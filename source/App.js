enyo.kind({
	name: "App",
	kind: "FittableRows",
	fit: true,
	components: [
		{kind: "enyo.Signals", onFileSelected: "fileSelected"},
		{kind: "enyo.Signals", onBack: "goBack", onbackbutton: "goBack"},
		{kind: "enyo.Signals", onError: "showError"},
		{ 	kind: "Panels",  
			fit: true,
			draggable: true, 
			classes: "panels enyo-border-box", 
			//arrangerKind: "enyo.CardSlideInArranger", 
			components: [
				{kind: "PDFScanner"},
				{kind: "PDFViewer", name: "pdfViewer"}
		]},
		{name: "errorDialog", kind: "onyx.Popup", modal: true, centered: true, classes: "popup", autoDismiss: false, components: [
			{ name: "errorDescription", classes: "errorDialogDescription", content: ""},
			{ name: "btn", kind : "onyx.Button", content: "OK", ontap: "closePopup", classes: "onyx-negative errorDialogBtn"}
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
	},

	showError: function(inSender, error) {
		this.$.errorDescription.setContent(error);
		this.$.errorDialog.show();
		return true;
	},

	closePopup: function() {
 		this.$.errorDialog.hide();
 		return true;
 	}

});


