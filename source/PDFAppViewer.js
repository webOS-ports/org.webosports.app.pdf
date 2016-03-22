var DEFAULT_URL = null;

info = {
	//url: 'assets/compressed.tracemonkey-pldi-09.pdf',
	url: 'assets/helloworld.pdf',
	page: 1,
	totalPages: 1,
	scale: null,
	rotation: 0,
	defaultScale: null

};

enyo.kind({
	name: "PDFAppViewer",
	kind: "FittableRows",
	published: {
		mixScale: 1.00,
		maxScale: 5
	},
	components: [
		{kind: "enyo.Signals", onNumPagesChanged: "numPagesChanged"},
		{kind: "enyo.Signals", onPageLoadStart: "pageLoadStart"},
		{kind: "enyo.Signals", onPageLoadEnd: "pageLoadEnd"},
		{kind: "enyo.Signals", onFileSelected: "openFile"},
		{name: "header", kind: "onyx.Toolbar", components:[
			{name: "title", content: "", style: "text-overflow: ellipsis; overflow:hidden; width: 170px;"},
			{kind: "onyx.Button", name: "SearchButton", id: "viewFind", ontap: "searchOpen", components: [
					{ kind: "Image", src: "assets/toolbarButton-search.png"}
				] },
			{kind: "onyx.PickerDecorator", style: "float: right; margin-top: 0px;", components: [
				{style: "min-width: 40px;"},
				{kind: "onyx.IntegerPicker", min: 1, max: 1, value: 1, onSelect: "pageSelected"}
			]}
		]},
		{ name: "outerContainer", id: "outerContainer", style: "position: relative; overflow: hidden;", components: [
			{ id: "mainContainer", components: [
				{name: "CanvasContainer", id: "viewerContainer", fit: true, components: [
					{name: "thumbnailView", id: "thumbnailView", style: "display: none;" },
					{name: "scroller", kind: "enyo.Scroller", touch: true, onScroll: "scroll", components: [
						{name: "canvas", id: "viewer",
							ongesturechange: "zoomChanged",
							ontap: "onTapped"
						}
					]}
				]}
			]},
			{name: "findbar", id: "findbar", style: "visibility: hidden", components: [
				{ name: "findInput", id: "findInput", kind: "onyx.Input", selectOnFocus: false,  defaultFocus: false, placeholder: "Find..."},
				{ kind: "onyx.Button", name: "findPrevious", id: "findPrevious", content: "Find Prev" },
				{ kind: "onyx.Button", name: "findNext", id: "findNext", content: "Find Next" },
				{ kind: "onyx.Checkbox", name: "findHighlightAll", id: "findHighlightAll", content: "Highlight All" },
				{ kind: "onyx.Checkbox", name: "findMatchCase", id: "findMatchCase", content: "Match Case" }
			]},
			{ name: "secondaryToolbar", id: "secondaryToolbar", style: "display: none", components: [
				{ name: "secondaryToolbarButtonContainer", components: [
					{ name: "secondaryPresentationMode", id: "secondaryPresentationMode" },
					{ name: "secondaryOpenFile", id: "secondaryOpenFile" },
					{ name: "secondaryPrint", id: "secondaryPrint" },
					{ name: "secondaryDownload", id: "secondaryDownload" },
					{ name: "secondaryViewBookmark", id: "secondaryViewBookmark" }
				]},
			]},
			{ name: "viewerContextMenu", id: "viewerContextMenu", style: "display: none", components: [
				{ name: "contextFirstPage", id: "contextFirstPage" },
				{ name: "contextLastPage", id: "contextLastPage" },
				{ name: "contextPageRotateCw", id: "contextPageRotateCw" },
				{ name: "contextPageRotateCcw", id: "contextPageRotateCcw" }
			]}
		]},
			{name: "footer", kind: "onyx.Toolbar", style: "height: 54px;", components: [
				{kind: "onyx.Grabber", ontap: "goBack"},
				{name: "ZoomButtons", defaultKind: "onyx.Button", style: "margin-left: 30;", components: [
					{name: "ZoomOutButton", content: "-", ontap: "zoomOut"},
					{name: "ZoomInButton", content: "+", ontap: "zoomIn"}
				]},
				{name: "RotateButtons", defaultKind: "onyx.Button", style: "margin-left: 30;", components: [
					{name: "RotateCounterclockwiseButton", content: "↶", ontap: "rotateCounterclockwise"},
					{name: "RotateClockwiseButton", content: "↷", ontap: "rotateClockwise"}
				]},
				{name: "PageCounter",
				defaultKind: enyo.kind({style: "display: inline-block; margin-right: 4px;"}),
				style: "float: right;",
				components: [
					{name: "PrevPageButton", content: "◂", ontap: "prevPage", style: "margin-right: 0.5em;"},
					{name: "PageNumber", content: info.page},
					{content: "/"},
					{name: "TotalPages", content: info.totalPages},
					{name: "NextPageButton", content: "▸", ontap: "nextPage", style: "margin-left: 0.5em;"}
				]}
			]},
		//]},
		{name: "busyPopup", kind: "onyx.Popup", centered: true, floating: true, scrim: true, components: [
			{kind: "onyx.Spinner"},
		]},
		{ name: "passwordOverlay", id: "passwordOverlay", style: "display: none", components: [
			{ name: "passwordText", id: "passwordText", content: "Enter the password to open this PDF file:" },
			{ name: "password", id: "password", kind: "onyx.Input" },
			{ kind: "onyx.Button", name: "passwordCancel", id: "passwordCancel", content: "Cancel" },
			{ kind: "onyx.Button", name: "passwordSubmit", id: "passwordSubmit", content: "OK" }
		]},
		{ name: "documentPropertiesOverlay", id: "documentPropertiesOverlay", style: "display: none;" },
		{ name: "otherHiddenControls", style: "display: none", components: [
			{ id: "scaleSelectContainer", components: [
				{ id: "scaleSelect", tag: "select", components: [
					{ tag: "option", value: 1, content: "100%" }
				]}
			]},
			{ id: "sidebarToggle" },
			{ id: "viewThumbnail" },
			{ id: "viewOutline" },
			{ id: "viewAttachments" },
			{ id: "previous" },
			{ id: "next" },
			{ id: "zoomIn" },
			{ id: "zoomOut" },
			{ id: "pageNumber" },
			{ id: "presentationMode" },
			{ id: "openFile" },
			{ id: "print" },
			{ id: "download" },
			{ id: "errorWrapper" },
			{ id: "errorMessage" },
			{ id: "errorClose" },
			{ id: "errorMoreInfo" },
			{ id: "errorShowMore" },
			{ id: "errorShowLess" },
			{ id: "loadingBar", components: [
				{ classes: "progress" }
			]},
			{ id: "numPages" },
			{ id: "customScaleOption", kind: "onyx.Input" },
			{ id: "firstPage" },
			{ id: "lastPage" },
			{ id: "viewBookmark" },
			{ id: "outlineView" },
			{ id: "attachmentsView" }
		]}
	],

	create: function() {
		this.inherited(arguments);
		if(enyo.platform.touch) {
			this.$.ZoomButtons.hide();
		}
		
		// Patch getVisibleElements to work with our scrollers.
		this.pseudoScrollElement = {
				scrollLeft: 0,
				scrollTop: 0,
				actualScrollDataSource() {
						return document.getElementById("viewer").parentNode.parentNode;
					},
				get clientWidth() {
						return this.actualScrollDataSource().clientWidth;
					},
				get clientHeight() {
						return this.actualScrollDataSource().clientHeight;
					}
			};
		var oldGetVisibleElements = window.getVisibleElements;
		window.getVisibleElements = function(pseudoScrollElement) { return function(scrollEl, views, sortByVisibility) {
				return oldGetVisibleElements(pseudoScrollElement, views, sortByVisibility);
			}; }(this.pseudoScrollElement);
	},
	
	reflow: function() {
		this.inherited(arguments);
		
		var headerFooterHeight = 0;
		if(this.$.header.getShowing())
		{
			headerFooterHeight = 54 + 54;
		}
		this.$.outerContainer.applyStyle("width", window.innerWidth + "px");
		this.$.outerContainer.applyStyle("height", window.innerHeight - headerFooterHeight + "px");
		this.$.scroller.applyStyle("height", window.innerHeight - headerFooterHeight + "px");
		
		this.$.title.applyStyle("width", (window.innerWidth - 190) + "px");
	},

	goBack: function(inSender, inEvent){
		enyo.Signals.send('onBack', {});
	},

	openFile: function(inSender, inEvent){
		var v = inEvent.file;
		enyo.log("Opening file: " + v);
		if(v) {

			if(info.pdf) {
				enyo.log("Cleaning up existing PDF Doc");
				info.pdf.cleanup();
				info.pdf.destroy();
			}

			this.$.title.setContent(inEvent.name);

			info.scale = null;
			info.defaultScale = null;
			info.page = 1;
			info.url = 	v;
			enyo.Signals.send('onPageLoadStart', {});
			//info.viewer = new PDFViewer({container: this.$.CanvasContainer.node, viewer: this.$.canvas.node, removePageBorders: true});
			//PDFJS.getDocument(info.url).then(this.getPdf, this.getDocumentError);
			//PDFViewerApplication.initialize();
			PDFViewerApplication.open(info.url).then(this.getPdf, this.getDocumentError);
		}
		
	},

	pageChanged: function(inSender, inEvent) {
		// reset the zooming when page changes.
		info.scale = null;
		this.$.integerPicker.setValue(info.page);
		this.$.PageNumber.setContent(info.page);
		if(info.page <= 1) {
			this.$.PrevPageButton.applyStyle("visibility", "hidden");
		}
		else {
			this.$.PrevPageButton.applyStyle("visibility", "visible");
		}
		if(info.page >= info.totalPages) {
			this.$.NextPageButton.applyStyle("visibility", "hidden");
		}
		else {
			this.$.NextPageButton.applyStyle("visibility", "visible");
		}
		
		// Hide the PDF.js pages which should not be visible.
		/*var canvas = document.getElementById("viewer");
		for(var c = 0; c < canvas.children.length; ++c) {
			if(canvas.children[c].hasAttribute("id") && canvas.children[c].id.substring(0, 13) == "pageContainer") {
				if(canvas.children[c].id == "pageContainer" + info.page) {
					canvas.children[c].style.display = "block";
				}
				else {
					canvas.children[c].style.display = "none";
				}
				canvas.children[c].style.marginBottom = canvas.parentNode.clientHeight - canvas.children[c].clientHeight;
			}
		}*/
		PDFViewerApplication.page = info.page;
		//PDFViewerApplication.forceRendering();
	},

	numPagesChanged: function(inSender, inEvent) {
		info.totalPages = inEvent.numPages;
		this.$.TotalPages.setContent(inEvent.numPages);
		this.$.integerPicker.setMax(inEvent.numPages);
		this.pageChanged(this, {page: info.page});
	},

	pageLoadStart: function(inSender, inEvent){
		this.$.busyPopup.show();
	},

	pageLoadEnd: function(inSender, inEvent){
		//this.$.scroller.stabilize();
		//this.$.scroller.scrollToTop();
		this.$.busyPopup.hide();
		this.pageChanged(this, {page: info.page});
	},

	prevPage: function() {
		if(info.page > 1) {
			info.page--;
			this.pageChanged(this, {page: info.page});
			//this.$.canvas.update();
		}
	},

	nextPage: function() {
		if(info.page < info.numPages) {
			info.page++;
			this.pageChanged(this, {page: info.page});
			//this.$.canvas.update();
		}
	},

	pageSelected: function(inSender, inEvent) {
		info.page = inEvent.content;
		this.pageChanged(this, {page: info.page});
	},

	onTapped: function(inSender, inEvent){
		
		if(!this.$.header.getShowing()){
			enyo.log("Showing Header");
			this.$.header.show();
			this.$.footer.show();
			this.reflow();
		} else{
			enyo.log("Hidding Header");
			this.$.header.hide();
			this.$.footer.hide();
			this.reflow();	
		}
	},

	zoomOut: function() {
		if(info.scale > 0.25) {
			info.scale -= 0.25;
			this.$.canvas.update();
		}
	},

	zoomIn: function() {
		if(info.scale < 5) {
			info.scale += 0.25;
			this.$.canvas.update();
		}
	},

	zoomChanged: function(inSender, inEvent) {
		//console.error(inEvent.scale);
		var newScale = this.limitScale(inEvent.scale);
		if(newScale != info.scale) {
			info.scale = newScale;
			enyo.job("updateCanvas", enyo.bind(this, "updateCanvas"), 25);
		}
       return true;
		
	},

	rotateCounterclockwise: function() {
		info.rotation = (info.rotation - 90) % 360;
		this.$.canvas.update();
	},

	rotateClockwise: function() {
		info.rotation = (info.rotation + 90) % 360;
		this.$.canvas.update();
	},

	limitScale: function(scale) {
		if(scale > this.maxScale) {
			scale = this.maxScale;
		} else if(scale < this.minScale) {
			scale = this.minScale;
		}
		return scale;
	},

	getPdf: function() {
		info.numPages = PDFViewerApplication.pagesCount;
		enyo.log("Number of Pages: " + info.numPages);
		//enyo.log(JSON.stringify(pdf.getMetadata()));
		enyo.Signals.send('onNumPagesChanged', {numPages: info.numPages});
		enyo.Signals.send('onPageLoadEnd');
	},


	getDocumentError: function(message, exception) {
		var loadingErrorMessage = 'An error occurred while loading the PDF.';

        if (exception && exception.name === 'InvalidPDFException') {
          var loadingErrorMessage = 'Invalid or corrupted PDF file.';
        }

        if (exception && exception.name === 'MissingPDFException') {
          var loadingErrorMessage = 'Missing PDF file.';
        }

        enyo.log("Error Loading PDF: " + loadingErrorMessage);
        enyo.Signals.send('onError', "Error Loading PDF: " + loadingErrorMessage);
	},

	scroll: function(inSender, inEvent) {
		this.pseudoScrollElement.scrollTop = inEvent.scrollBounds.top;
		this.pseudoScrollElement.scrollLeft = inEvent.scrollBounds.left;
	},

	searchOpen: function(inSender, inEvent) {
	}
	
});


