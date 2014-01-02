info = {
	//url: 'assets/compressed.tracemonkey-pldi-09.pdf',
	url: 'assets/helloworld.pdf',
	page: 1,
	totalPages: 1,
	scale: 1.0
};

enyo.kind({
	name: "App",
	kind: "FittableRows",
	components: [
		{kind: "enyo.Signals", onNumPagesChanged: "numPagesChanged"},
		{kind: "enyo.Signals", onPageLoadStart: "pageLoadStart"},
		{kind: "enyo.Signals", onPageLoadEnd: "pageLoadEnd"},

		{name: "header", kind: "onyx.Toolbar", components:[
			{ name: "busySpinner", kind: "Image", src: "assets/spinner.gif", showing: false, style: "float: right;"},
			{name: "fileInput", kind: "enyo.Input", value: "assets/compressed.tracemonkey-pldi-09.pdf"},
			{ kind: "onyx.Icon", src: "assets/open-external.png", style: "margin-top:-5px;", ontap: "openFile" }
			/*  WebOS Ports filePicker is not quite ready yet  */
			//{name: "filePicker", kind: "enyo.FilePicker", fileType:["pdf"], onPickFile: "fileSelected"}
			
		]},
		{name: "CanvasContainer", fit: true, components: [
			{kind: "enyo.Scroller", touch: true, style: "width: 100%; height: 100%;", components: [
				{name: "canvas", kind: "enyo.Canvas", ontap: "zoomIn", components: [
					{name: "pdfViewer", kind: "PDFViewer"}
				]}
			]}
		]},
		{kind: "onyx.Toolbar", style: "height: 54px;", components: [
			{name: "PageButtons",
			defaultKind: "onyx.Button",
			style: "margin: 0; float: right;",
			components: [
				{name: "PrevPageButton", content: "<", ontap: "prevPage"},
				{name: "NextPageButton", content: ">", ontap: "nextPage"}
			]},
			{name: "PageCounter",
			defaultKind: enyo.kind({style: "display: inline-block; margin-right: 4px;"}),
			style: "float: right;",
			components: [
				{content: "Page"},
				{name: "PageNumber", content: info.page},
				{content: "of"},
				{name: "TotalPages", content: info.totalPages}
			]},
			{name: "ZoomButtons",
			defaultKind: "onyx.Button",
			style: "margin: 0; float: left;",
			components: [
				{name: "ZoomOutButton", content: "-", ontap: "zoomOut"},
				{name: "ZoomInNextPageButton", content: "+", ontap: "zoomIn"}
			]},
		]}
	],

	reflow: function() {
		this.inherited(arguments);

		this.$.canvas.attributes.width = window.innerWidth;
		this.$.canvas.attributes.height = window.innerHeight;
	},

	openFile: function(inSender, inEvent){
		var v = this.$.fileInput.getValue();
		enyo.log("Opening file: " + v);
		if(v) {

			if(info.pdf) {
				enyo.log("Cleaning up existing PDF Doc");
				info.pdf.cleanup();
				info.pdf.destroy();
			}

			info.url = 	v;
			enyo.Signals.send('onPageLoadStart', {});
			PDFJS.getDocument(info.url).then(this.getPdf, this.getDocumentError);
		}
		
	},

	pageChanged: function(inSender, inEvent) {
		this.$.PrevPageButton.setDisabled(inEvent.page == 1 ? true : false);
		this.$.NextPageButton.setDisabled(inEvent.page == info.numPages ? true : false);
		this.$.PageNumber.setContent(info.page);
	},

	numPagesChanged: function(inSender, inEvent) {
		info.totalPages = inEvent.numPages;
		this.$.TotalPages.setContent(inEvent.numPages);
		this.pageChanged(this, {page: info.page});
		this.$.canvas.update();
	},

	pageLoadStart: function(inSender, inEvent){
		this.$.busySpinner.show();
	},

	pageLoadEnd: function(inSender, inEvent){
		this.$.busySpinner.hide();
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

	getPdf: function(pdf) {
		info.numPages = pdf.pdfInfo.numPages;
		info.pdf = pdf;
		enyo.log(JSON.stringify(pdf.getMetadata()));
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
	}

});

enyo.kind({
	name: "PDFViewer",
	kind: "enyo.canvas.Control",
	
	create: function() {
		this.inherited(arguments);
	},

	render: function(){
		this.inherited(arguments);
		this.renderPage();

	},

	renderPage: function(){
		if(info.pdf){
			enyo.Signals.send('onPageLoadStart', {});
			info.pdf.getPage(info.page).then(function drawPage(page) {

				var scale = info.scale;
				var viewport = page.getViewport(scale);
				
				var canvas = document.getElementById('app_canvas');
				var context = canvas.getContext('2d');
				canvas.height = viewport.height;
				canvas.width = viewport.width;
				
				page.render({canvasContext: context, viewport: viewport}).then(function renderComplete(){
					enyo.Signals.send('onPageLoadEnd', {});
				});
				
			});
		}
	}

	
});


