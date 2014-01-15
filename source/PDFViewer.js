info = {
	//url: 'assets/compressed.tracemonkey-pldi-09.pdf',
	url: 'assets/helloworld.pdf',
	page: 1,
	totalPages: 1,
	scale: 1.0
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
			{kind: "onyx.Grabber", ontap: "goBack"},
			{name: "title", content: "", style: "text-overflow: ellipsis; overflow:hidden; width: 170px;"},
			{kind: "onyx.PickerDecorator", style: "float: right; margin-top: 0px;", components: [
				{style: "min-width: 40px;"},
				{kind: "onyx.IntegerPicker", min: 1, max: 1, value: 1, onSelect: "pageSelected"}
			]}
		]},
		{name: "CanvasContainer", fit: true, components: [
			{kind: "enyo.Scroller", touch: true, style: "width: 100%; height: 100%;", gesturechange: "zoomChanged", gestureend: "zoomChanged", components: [
				{name: "canvas", kind: "enyo.Canvas", components: [
					{name: "pdfPage", kind: "PDFPage"}
				]}
			]}
		]},
		{kind: "onyx.Toolbar", style: "height: 54px;", components: [
			{name: "PageButtons", defaultKind: "onyx.Button", style: "margin: 0; float: right;", components: [
				{name: "PrevPageButton", content: "<", ontap: "prevPage"},
				{name: "NextPageButton", content: ">", ontap: "nextPage"}
			]},
			{name: "PageCounter",
			defaultKind: enyo.kind({style: "display: inline-block; margin-right: 4px;"}),
			style: "float: right;",
			components: [
				{name: "PageNumber", content: info.page},
				{content: "/"},
				{name: "TotalPages", content: info.totalPages}
			]},
			{name: "ZoomButtons", defaultKind: "onyx.Button", style: "margin: 0; float: left;", components: [
				{name: "ZoomOutButton", content: "-", ontap: "zoomOut"},
				{name: "ZoomInNextPageButton", content: "+", ontap: "zoomIn"}
			]},
		]},
		{name: "busyPopup", kind: "onyx.Popup", centered: true, floating: true, scrim: true, components: [
			{kind: "onyx.Spinner"},
		]}
	],

	create: function() {
		this.inherited(arguments);
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

			info.scale = 1.0;
			info.page = 1;
			info.url = 	v;
			enyo.Signals.send('onPageLoadStart', {});
			PDFJS.getDocument(info.url).then(this.getPdf, this.getDocumentError);
		}
		
	},

	pageChanged: function(inSender, inEvent) {
		this.$.PrevPageButton.setDisabled(inEvent.page == 1 ? true : false);
		this.$.NextPageButton.setDisabled(inEvent.page == info.numPages ? true : false);
		this.$.integerPicker.setValue(info.page);
		this.$.PageNumber.setContent(info.page);
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
		console.error(inEvent.scale);
		var newScale = this.limitScale(inEvent.scale/2);
		if(newScale != info.scale) {
			info.scale = newScale;
			enyo.job("updateCanvas", enyo.bind(this, "updateCanvas"), 50);
		}
       return true;
		
	},

	updateCanvas: function(inSender, inEvent) {
		console.warn("Sclaing to " + info.scale);
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
	}
	
});


