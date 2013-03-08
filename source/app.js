enyo.kind({
	name: "App",
	kind: "FittableRows",
	classes: "enyo-fit dark-scene",
	components: [
		{id: "outerContainer",
		components: [
			{kind: "FittableRows",
			id: "sidebarContainer",
			components: [
				{kind: "onyx.Toolbar", components: [
					{kind: "onyx.RadioGroup", components: [
						{id: "viewThumbnail", active: true, components:[
							{kind: "enyo.Image", src: "assets/toolbarButton-viewThumbnail.png"}
						]},
						{id: "viewOutline", components:[
							{kind: "enyo.Image", src: "assets/toolbarButton-viewOutline.png"}
						]}
					]}
				]},
				{style: "position: relative;", fit: true, components: [
					{id: "thumbnailView"},
					{id: "outlineView", classes: "hidden"}
				]}
			]},
			{id: "mainContainer",
			components: [
				{id: "viewerContainer", components: [
					{id: "viewer"}
				]},
				{tag: "menu",
				id: "viewerContextMenu",
				components: [
					{tag: "menuitem", label: "First Page", id: "first_page"},
					{tag: "menuitem", label: "Last Page",	id: "last_page"},
					{tag: "menuitem", label: "Rotate Counter-Clockwise", id: "page_rotate_ccw"},
					{tag: "menuitem", label: "Rotate Clockwise", id: "page_rotate_cw"}
				]},
				{tag: "div",
				id: "findbar",
				classes: "findbar hidden doorHanger hiddenSmallView",
				components: [
					{tag: "input", id: "findInput", classes: "toolbarField"},
					{tag: "div",
					classes: "splitToolbarButton",
					components: [
						{tag: "button", id: "findPrevious",	classes: "toolbarButton findPrevious"},
						{tag: "div",	classes: "splitToolbarButtonSeparator"},
						{tag: "button", id: "findNext",	classes: "toolbarButton findNext"}
					]},
					{tag: "checkbox",/*type: "checkbox",*/	id: "findHighlightAll",	classes: "toolbarField", label: "test"}, 
					{tag: "checkbox",/*type: "checkbox",*/ id: "findMatchCase", classes: "toolbarField"},
					{tag: "span", id: "findMsg", classes: "toolbarLabel"}
				]},
				{tag: "div",
				classes: "toolbar",
				components: [
					{tag: "div",
					id: "toolbarContainer",
					components: [
						{tag: "div",
						id: "toolbarViewer",
						components: [
							{tag: "div", id: "toolbarViewerLeft", components: [
							{tag: "button", id: "sidebarToggle", classes: "toolbarButton"},
							{tag: "div", classes: "toolbarButtonSpacer"},
							{tag: "button", id: "viewFind", classes: "toolbarButton group hiddenSmallView"},
							{tag: "div",
							classes: "splitToolbarButton",
							components: [
								{tag: "button", id: "previous", classes: "toolbarButton pageUp",
								components: [
									{tag: "span", value: "Previous"}
								]},
								{tag: "div",	classes: "splitToolbarButtonSeparator"},
								{tag: "button",
								id: "next",
								classes: "toolbarButton pageDown",
								components: [
									{tag: "span", value: "Next"}
								]}
							]},
							{tag: "label", id: "pageNumberLabel", classes: "toolbarLabel", value: "Page"},
							{tag: "input",	id: "pageNumber",	classes: "toolbarField pageNumber", value: "1"},
							{tag: "span", id: "numPages", classes: "toolbarLabel"}
						]},
						{tag: "div",
						id: "toolbarViewerRight",
						components: [
							{tag: "input", id: "fileInput", classes: "fileInput"},
							{tag: "button", id: "fullscreen", classes: "toolbarButton fullscreen hiddenSmallView"},
							{tag: "button", id: "openFile", classes: "toolbarButton openFile hiddenSmallView"},
							{tag: "button", id: "print", classes: "toolbarButton print"},
							{tag: "button", id: "download",	classes: "toolbarButton download"},
							{tag: "a", id: "viewBookmark", classes: "toolbarButton bookmark hiddenSmallView"}
						]},
						{tag: "div",
						classes: "outerCenter",
						components: [{
						tag: "div",
						id: "toolbarViewerMiddle",
						classes: "innerCenter",
						components: [
							{tag: "div",
							classes: "splitToolbarButton",
							components: [
								{tag: "button",
								classes: "toolbarButton zoomOut",
								id: "zoom_out",
								components: [
									{tag: "span", value: "Zoom Out"}
								]},
								{tag: "div", classes: "splitToolbarButtonSeparator"},
								{tag: "button",
								classes: "toolbarButton zoomIn",
								id: "zoom_in",
								components: [
									{tag: "span", value: "Zoom In"}
								]}
							]}
						]},
						{tag: "span",
						id: "scaleSelectContainer",
						classes: "dropdownToolbarButton",
						components: [
							{tag: "select",
							id: "scaleSelect",
							title: "Zoom",
							components: [
								{tag: "option", id: "pageAutoOption",	value: "auto", selected: "selected", content: "auto"},
								{tag: "option", id: "pageActualOption",	value: "page-actual", content: "page-actual"},
								{tag: "option", id: "pageFitOption", value: "page-fit", content: "page-fit"},
								{tag: "option", id: "pageWidthOption", value: "page-width", content: "page-width"},
								{tag: "option", id: "customScaleOption",	value: "custom"},
								{tag: "option",/*value: 0.5,*/ content: "50%"},
								{tag: "option",/*value: 0.75, content: "75%"},
								{tag: "option",/*value: 1,*/ content: "100%"},
								{tag: "option",/*value: 1.25,*/ content: "125%"},
								{tag: "option",/*value: 1.5,*/ content: "150%"},
								{tag: "option",/*value: 2*/ content: "200%"}
							]}
						]}
					]}
				]}
			]}
		]}, 
		{tag: "div",
		id: "loadingBox",
		components: [
			{tag: "div", id: "loading"},
			{tag: "div",
				id: "loadingBar",
				components: [
					{tag: "div",	classes: "progress"}
				]}
			]},
			{tag: "div",
			id: "errorWrapper",
			components: [
				{tag: "div",
				id: "errorMessageLeft",
				components: [
					{tag: "span", id: "errorMessage"},
					{tag: "button", id: "errorShowMore"},
					{tag: "button", id: "errorShowLess"}
				]},
				{tag: "div",
				id: "errorMessageRight",
				components: [
					{tag: "button", id: "errorClose"}
				]},
				{tag: "div",
				classes: "clearBoth",
				components: [
					{tag: "textarea", id: "errorMoreInfo"}
				]}
			]}
		]}
	]}
]});
