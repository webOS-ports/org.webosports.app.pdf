// A pointer used and only then checked for null: the check comes too late.
@@
expression E;
identifier fld;
@@
* E->fld
  ... when != E = ...
* if (E == nullptr || ...) { ... }
