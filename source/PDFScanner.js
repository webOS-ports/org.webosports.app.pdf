enyo.kind({
	name: "PDFScanner",
	kind: "FittableRows",
	fit: true,
	components: [
		{name: "header", kind: "onyx.Toolbar", content: "Select PDF File"},
        { kind: "List", classes: "enyo-list", fit: true, touch: true, count: 0, onSetupItem: "setupItem", components: [
        	{ classes: "item enyo-border-box", layoutKind: "FittableColumnsLayout", style: "margin: 5px;", ontap: "selectItem", components: [
				{kind: "Image", src: "assets/pdfsmall.png", style: "width: 30px; height: 30px;"},
				{name: "file", style: "margin-left: 10px; font-weight: bolder;", fit: true}
			]},
        ]},
        { name: "fileScannerService",
          kind: "enyo.PalmService",
          service: "palm://org.webosports.app.pdf.service",
          method: "find",
          subscribe: false,
          onComplete: "fileScanComplete"
        }
	],

	create: function() {
		this.inherited(arguments);
		this.fileList = [];
		if(enyo.platform.webos) {
			this.$.fileScannerService.send({});	
		} else{
			// For developing on Browser, setup some fake data
			this.fileScanComplete({},{data: {code: 0, files: [{d: "assets", n: "helloworld.pdf"}, {d: "assets", n: "compressed.tracemonkey-pldi-09.pdf"}]}});
		}
		
	},
	
	fileScanComplete: function(inSender, inEvent){
		var result = inEvent.data;
		//enyo.log(JSON.stringify(result));
		if(result.code === 0) {
			this.fileList = result.files;	
			this.$.list.setCount(this.fileList.length);
			this.$.list.reset();
		} else {
			enyo.log("Failed to find PDF Files: " + JSON.stringify(result));
		}
		
	},

	setupItem:  function(inSender, inEvent) {
    	var r = this.fileList[inEvent.index];
    	if(r){
    		this.$.file.setContent(r.n);
    	}
    	return true;

	},

	selectItem: function(inSender, inEvent) {
    	var r = this.fileList[inEvent.index];
    	if(r) {
    		enyo.Signals.send('onFileSelected', {file: r.d + '/' + r.n, name: r.n});
    	}
	}

});


