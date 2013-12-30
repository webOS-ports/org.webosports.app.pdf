//PDFJS.disableFontFace  = true;
//PDFJS.disableWorker = true;
//PDFJS.workerSrc = 'pdf.worker.js';

info = {
	//url: 'http://cdn.mozilla.net/pdfjs/helloworld.pdf',
	url: 'assets/compressed.tracemonkey-pldi-09.pdf',
	//url: 'http://mozilla.github.io/pdf.js/web/compressed.tracemonkey-pldi-09.pdf',
	//url: 'https://github.com/mozilla/pdf.js/blob/master/examples/text-selection/pdf/TestDocument.pdf?raw=true',
	page: 1,
	totalPages: 1,
	scale: 1.0
};

enyo.kind({
	name: "App",
	kind: "FittableRows",
	components: [
		{kind: "enyo.Signals", onNumPagesChanged: "numPagesChanged"},

		{kind: "onyx.Toolbar"},
		{name: "CanvasContainer", fit: true, components: [
			{kind: "enyo.Scroller", touch: true, style: "width: 100%; height: 100%;", components: [
				{kind: "enyo.Canvas", components: [
					{kind: "PDFViewer"}
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
			]}
		]}
	],

	reflow: function() {
		this.inherited(arguments);

		this.$.canvas.attributes.width = window.innerWidth;
		this.$.canvas.attributes.height = window.innerHeight;
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
	}
});

enyo.kind({
	name: "PDFViewer",
	kind: "enyo.canvas.Control",
	
	create: function() {
		this.inherited(arguments);
		PDFJS.getDocument(info.url).then(this.getPdf);
	},

	render: function(){
		this.inherited(arguments);
		//enyo.log("render="  + JSON.stringify(info));
		this.renderPage();

	},

	renderPage: function(){
		if(info.pdf){
			info.pdf.getPage(info.page).then(function getPageHelloWorld(page) {

				var scale = info.scale;
				var viewport = page.getViewport(scale);
				
				var canvas = document.getElementById('app_canvas');
				var context = canvas.getContext('2d');
				canvas.height = viewport.height;
				canvas.width = viewport.width;

				page.render({canvasContext: context, viewport: viewport});
			});
		}
	},

	getPdf: function(pdf) {
		enyo.log("Loading PDF file: "  + JSON.stringify(info));

		info.numPages = pdf.pdfInfo.numPages;
		info.pdf = pdf;
		enyo.Signals.send('onNumPagesChanged', {numPages: info.numPages});
	}
});
