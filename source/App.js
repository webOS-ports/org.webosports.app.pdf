enyo.kind({
	name: "App",
	kind: "FittableRows",
	fit: true,
	components: [
		{kind: "enyo.Signals", onFileSelected: "fileSelected"},
		{kind: "enyo.Signals", onBack: "goBack"},
		{ 	kind: "Panels",  
			fit: true,
			draggable: true, 
			classes: "panels enyo-border-box", 
			//arrangerKind: "enyo.CardSlideInArranger", 
			components: [
				{kind: "PDFScanner"},
				{kind: "PDFViewer", name: "pdfViewer"}
		]}
	],

	create: function() {
		this.inherited(arguments);
	},

	fileSelected: function(inSender, inEvent){
		this.$.panels.next();
	},

	goBack: function(inSender, inEvent){
		this.$.panels.previous();
	}

});


