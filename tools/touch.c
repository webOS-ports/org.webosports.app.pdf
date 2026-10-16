/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * touch - fingers on a device's touch screen, for the device tests: writes
 * multi-touch events to its evdev node, in screen pixels scaled to the
 * node's axes. Protocol B (slots) where the node has ABS_MT_SLOT, protocol A
 * (SYN_MT_REPORT per finger) where it does not - the mindphone's mtk-tpd
 * and the TouchPad's controller; the kernel drops events for axes a node
 * lacks, so slots there would never arrive.
 *
 *   touch <dev> <screen w> <screen h> tap X Y
 *   touch <dev> <screen w> <screen h> doubletap X Y
 *   touch <dev> <screen w> <screen h> hold X Y MS
 *   touch <dev> <screen w> <screen h> swipe X1 Y1 X2 Y2 MS
 *   touch <dev> <screen w> <screen h> pinch CX CY FROM TO MS   (finger gap, pixels)
 *   touch <dev> 0 0 keys DIGITS        (a keypad: "7777" taps 7 four times;
 *                                       a space waits 1.5 s, for T9; a-z
 *                                       type on a keyboard's letter keys)
 *
 * Static, so it runs on any image: tools/device-test.sh builds it with the
 * build's cross compiler.
 */

#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

static int fd = -1;
static struct input_absinfo ax, ay;
static int screen_w, screen_h;
static int next_tracking_id = 100;
static int slots;

static void emit(int type, int code, int value)
{
    struct input_event ev;
    memset(&ev, 0, sizeof ev);
    ev.type = (unsigned short)type;
    ev.code = (unsigned short)code;
    ev.value = value;
    if (write(fd, &ev, sizeof ev) != (ssize_t)sizeof ev) {
        fprintf(stderr, "touch: write: %s\n", strerror(errno));
        exit(1);
    }
}

static void sync_frame(void)
{
    emit(EV_SYN, SYN_REPORT, 0);
}

static void pause_ms(int ms)
{
    struct timespec t = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&t, NULL);
}

static int scale(int v, int screen, const struct input_absinfo *a)
{
    long range = (long)a->maximum - a->minimum;
    return a->minimum + (int)(range * v / (screen > 1 ? screen - 1 : 1));
}

/* Fingers 0..n-1 at the given points; down says whether they touch. */
static void fingers(int n, const int *x, const int *y, int down, int *ids)
{
    if (!slots) {
        for (int i = 0; down && i < n; ++i) {
            if (ids[i] < 0)
                ids[i] = next_tracking_id++;
            emit(EV_ABS, ABS_MT_TRACKING_ID, ids[i]);
            emit(EV_ABS, ABS_MT_POSITION_X, scale(x[i], screen_w, &ax));
            emit(EV_ABS, ABS_MT_POSITION_Y, scale(y[i], screen_h, &ay));
            emit(EV_ABS, ABS_MT_TOUCH_MAJOR, 8);
            emit(EV_ABS, ABS_MT_PRESSURE, 50);
            emit(EV_SYN, SYN_MT_REPORT, 0);
        }
        if (!down) {
            for (int i = 0; i < n; ++i)
                ids[i] = -1;
            emit(EV_SYN, SYN_MT_REPORT, 0);
        }
        emit(EV_KEY, BTN_TOUCH, down ? 1 : 0);
        sync_frame();
        return;
    }
    for (int i = 0; i < n; ++i) {
        emit(EV_ABS, ABS_MT_SLOT, i);
        if (down) {
            if (ids[i] < 0)
                ids[i] = next_tracking_id++;
            emit(EV_ABS, ABS_MT_TRACKING_ID, ids[i]);
            emit(EV_ABS, ABS_MT_POSITION_X, scale(x[i], screen_w, &ax));
            emit(EV_ABS, ABS_MT_POSITION_Y, scale(y[i], screen_h, &ay));
            emit(EV_ABS, ABS_MT_TOUCH_MAJOR, 8);
            emit(EV_ABS, ABS_MT_PRESSURE, 50);
        } else {
            emit(EV_ABS, ABS_MT_TRACKING_ID, -1);
            ids[i] = -1;
        }
    }
    emit(EV_KEY, BTN_TOUCH, down ? 1 : 0);
    if (n > 0 && down) {
        emit(EV_ABS, ABS_X, scale(x[0], screen_w, &ax));
        emit(EV_ABS, ABS_Y, scale(y[0], screen_h, &ay));
    }
    sync_frame();
}

static void tap(int x, int y, int hold)
{
    int ids[1] = { -1 };
    fingers(1, &x, &y, 1, ids);
    pause_ms(hold);
    fingers(1, &x, &y, 0, ids);
}

static void move(int n, const int *x1, const int *y1, const int *x2, const int *y2, int ms)
{
    int ids[2] = { -1, -1 };
    int x[2], y[2];
    const int steps = ms / 16 > 2 ? ms / 16 : 2;
    for (int s = 0; s <= steps; ++s) {
        for (int i = 0; i < n; ++i) {
            x[i] = x1[i] + (x2[i] - x1[i]) * s / steps;
            y[i] = y1[i] + (y2[i] - y1[i]) * s / steps;
        }
        fingers(n, x, y, 1, ids);
        pause_ms(16);
    }
    fingers(n, x, y, 0, ids);
}

static int arg(char **argv, int i)
{
    return atoi(argv[i]);
}

int main(int argc, char **argv)
{
    if (argc < 5) {
        fprintf(stderr, "usage: touch <dev> <w> <h> tap|doubletap|hold|swipe|pinch ...\n");
        return 2;
    }
    if (strcmp(argv[4], "keys") == 0 && argc == 6) {
        static const int codes[10] = { KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9 };
        static const int letters[26] = {
            KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J, KEY_K, KEY_L, KEY_M,
            KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z
        };
        fd = open(argv[1], O_WRONLY | O_CLOEXEC);
        if (fd < 0) {
            fprintf(stderr, "touch: %s: %s\n", argv[1], strerror(errno));
            return 1;
        }
        for (const char *c = argv[5]; *c; ++c) {
            if (*c == ' ') {
                pause_ms(1500);
                continue;
            }
            int code;
            if (*c >= '0' && *c <= '9')
                code = codes[*c - '0'];
            else if (*c >= 'a' && *c <= 'z')
                code = letters[*c - 'a'];
            else
                continue;
            emit(EV_KEY, code, 1);
            sync_frame();
            pause_ms(40);
            emit(EV_KEY, code, 0);
            sync_frame();
            pause_ms(c[1] == *c ? 150 : 400);
        }
        close(fd);
        return 0;
    }
    fd = open(argv[1], O_WRONLY | O_CLOEXEC);
    if (fd < 0 || ioctl(fd, EVIOCGABS(ABS_MT_POSITION_X), &ax) < 0
        || ioctl(fd, EVIOCGABS(ABS_MT_POSITION_Y), &ay) < 0) {
        fprintf(stderr, "touch: %s: %s\n", argv[1], strerror(errno));
        return 1;
    }
    struct input_absinfo slot;
    slots = ioctl(fd, EVIOCGABS(ABS_MT_SLOT), &slot) == 0 && slot.maximum > 0;
    screen_w = arg(argv, 2);
    screen_h = arg(argv, 3);
    const char *what = argv[4];

    if (strcmp(what, "tap") == 0 && argc == 7) {
        tap(arg(argv, 5), arg(argv, 6), 40);
    } else if (strcmp(what, "doubletap") == 0 && argc == 7) {
        tap(arg(argv, 5), arg(argv, 6), 40);
        pause_ms(90);
        tap(arg(argv, 5), arg(argv, 6), 40);
    } else if (strcmp(what, "hold") == 0 && argc == 8) {
        tap(arg(argv, 5), arg(argv, 6), arg(argv, 7));
    } else if (strcmp(what, "swipe") == 0 && argc == 10) {
        int x1 = arg(argv, 5), y1 = arg(argv, 6), x2 = arg(argv, 7), y2 = arg(argv, 8);
        move(1, &x1, &y1, &x2, &y2, arg(argv, 9));
    } else if (strcmp(what, "pinch") == 0 && argc == 10) {
        int cx = arg(argv, 5), cy = arg(argv, 6), from = arg(argv, 7) / 2, to = arg(argv, 8) / 2;
        int x1[2] = { cx - from, cx + from }, y1[2] = { cy, cy };
        int x2[2] = { cx - to, cx + to }, y2[2] = { cy, cy };
        move(2, x1, y1, x2, y2, arg(argv, 9));
    } else {
        fprintf(stderr, "touch: bad arguments\n");
        return 2;
    }
    close(fd);
    return 0;
}
