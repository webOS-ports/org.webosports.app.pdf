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
	name: "PDFViewer",
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
			{kind: "onyx.PickerDecorator", style: "float: right; margin-top: 0px;", components: [
				{style: "min-width: 40px;"},
				{kind: "onyx.IntegerPicker", min: 1, max: 1, value: 1, onSelect: "pageSelected"}
			]}
		]},
		{name: "CanvasContainer", fit: true, components: [
			{kind: "enyo.Scroller", touch: true, style: "width: 100%; height: 100%;", onScrollStart: "scrollStart", onScrollStop: "scrollStop", onScroll: "scroll", components: [
				{name: "canvas", kind: "enyo.Canvas", 
					//ongesturestart: "zoomChanged",
					ongesturechange: "zoomChanged",
					//ongestureend: "zoomChanged",
					ontap: "onTapped",
					components: [
					{name: "pdfPage", kind: "PDFPage"}
				]}
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
		{name: "busyPopup", kind: "onyx.Popup", centered: true, floating: true, scrim: true, components: [
			{kind: "onyx.Spinner"},
		]}
	],

	create: function() {
		this.inherited(arguments);
		if(enyo.platform.touch) {
			this.$.ZoomButtons.hide();
		}
	},
	
	reflow: function() {
		this.inherited(arguments);

		this.$.canvas.attributes.width = window.innerWidth;
		this.$.canvas.attributes.height = window.innerHeight;

		this.$.title.applyStyle("width", (window.innerWidth - 160) + "px");
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
			PDFJS.getDocument(info.url).then(this.getPdf, this.getDocumentError);
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
	},

	numPagesChanged: function(inSender, inEvent) {
		info.totalPages = inEvent.numPages;
		this.$.TotalPages.setContent(inEvent.numPages);
		this.$.integerPicker.setMax(inEvent.numPages);
		this.pageChanged(this, {page: info.page});
		this.$.canvas.update();
	},

	pageLoadStart: function(inSender, inEvent){
		this.$.busyPopup.show();
	},

	pageLoadEnd: function(inSender, inEvent){
		this.$.scroller.stabilize();
		this.$.scroller.scrollToTop();
		this.$.busyPopup.hide();
	},

	prevPage: function() {
		if(info.page > 1) {
			info.page--;
			this.pageChanged(this, {page: info.page});
			this.$.canvas.update();
		}
	},

	nextPage: function() {
		if(info.page < info.numPages) {
			info.page++;
			this.pageChanged(this, {page: info.page});
			this.$.canvas.update();
		}
	},

	pageSelected: function(inSender, inEvent) {
		info.page = inEvent.content;
		this.pageChanged(this, {page: info.page});
		this.$.canvas.update();
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

	updateCanvas: function(inSender, inEvent) {
		//console.warn("Sclaing to " + info.scale);
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

	getPdf: function(pdf) {
		info.numPages = pdf.pdfInfo.numPages;
		info.pdf = pdf;
		enyo.log("Number of Pages: " + info.numPages);
		//enyo.log(JSON.stringify(pdf.getMetadata()));
		enyo.Signals.send('onNumPagesChanged', {numPages: info.numPages});
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


	scrollStart: function(inSender, inEvent) {
		//enyo.log("scrollStart");
		this.overScrollCount  = 0;
		this.checkForOverScroll = true;
		//this.scrollStartPos = -1*this.$.scroller.getScrollTop();

	},

	scrollStop: function(inSender, inEvent) {
		//enyo.log("scrollStop");
		this.checkForOverScroll = false;
	},

	scroll: function(inSender, inEvent) {

		if(this.checkForOverScroll){
			// throttle the events
			enyo.job("checkOverScroll", enyo.bind(this, "checkOverScroll"), 25);	
		}
		
	},

	checkOverScroll: function(inSender, inEvent) {
		var s = this.$.scroller.getStrategy().$.scrollMath
		var over = -1*this.$.scroller.getScrollTop();

		if (s.isInOverScroll()) {

			//enyo.log("Overscroll: " + over);
			//enyo.log("overScrollCount: " + this.overScrollCount);

			// Add a bit of resistance before triggering page navigation to prevent accidental navigation
			if(this.overScrollCount > 15) {
				if(over > 0){
					this.prevPage()	;
				} else {
					this.nextPage();
				}
				this.checkForOverScroll = false;
				this.overScrollCount = 0;
			} else {
				this.overScrollCount = this.overScrollCount + 1;
			}
		}
		
	}
	
});


