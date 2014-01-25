enyo.kind({
	name: "PDFScanner",
	kind: "FittableRows",
	fit: true,
	components: [
		{name: "header", kind: "onyx.Toolbar", components:[
			{kind: "onyx.InputDecorator", components: [
				{ name: "filterField", kind: "onyx.Input", selectOnFocus: false,  defaultFocus: false, placeholder: "Search...", onkeyup: "filterInputChange", onchange: "filterInputChange", onclear: "resetFilter"},
				{ kind: "Image", src: "assets/toolbarButton-search.png"}
			]}
		]},
        { kind: "List", classes: "enyo-list", fit: true, touch: true, count: 0, onSetupItem: "setupItem", components: [
        	{ classes: "item enyo-border-box", layoutKind: "FittableColumnsLayout", style: "margin: 5px;", ontap: "selectItem", components: [
				{kind: "Image", src: "assets/pdf_32.png", style: "width: 30px; height: 30px;"},
				{name: "file", style: "margin-left: 10px; font-weight: bolder;", fit: true}
			]},
        ]},
        { name: "fileScannerService",
          kind: "enyo.PalmService",
          service: "palm://org.webosports.app.pdf.service",
          method: "find",
          subscribe: false,
          onComplete: "fileScanComplete"
        },
        {name: "busyPopup", kind: "onyx.Popup", centered: true, floating: true, scrim: true, components: [
			{kind: "onyx.Spinner"},
		]},
	],

	create: function() {
		this.inherited(arguments);
		this.fileList = [];
		this.fileFilterList = [];

		// do this async to reduce app load times
		 enyo.asyncMethod(this, function() {
		 	this.$.busyPopup.show();
    		this.scanFiles();
	    });
	},

	reflow: function() {
		this.inherited(arguments);
		this.$.filterField.applyStyle("width", (this.hasNode().offsetWidth - 52) + "px");
	},

	scanFiles: function() {
		enyo.log("Platform: " + JSON.stringify(enyo.platform));

		if(typeof PalmServiceBridge === 'undefined') {
 			enyo.log("Not a WebOS Platform , using mock service results instead");

			this.fileScanComplete({},	
				{data: {
						code: 0, 
						files: []
						}
				}
			);	
		} else{
			this.$.fileScannerService.send({});						
		}

	},

	fileScanComplete: function(inSender, inEvent){
		var result = inEvent.data;
		//enyo.log(JSON.stringify(result));
		this.$.busyPopup.hide();
		if(result.code === 0) {
			this.fileList = result.files;	
		} else {
			enyo.log("Failed to find PDF Files: " + JSON.stringify(result));
			enyo.Signals.send('onError', "Failed to find PDF Files");
		}

		// Append the examples 

		this.fileList.push({d: "assets", n: "helloworld.pdf"});
		this.fileList.push({d: "assets", n: "compressed.tracemonkey-pldi-09.pdf"});

		this.fileFilterList = this.fileList;
		this.$.list.setCount(this.fileList.length);
		this.$.list.reset();
		
	},

	setupItem:  function(inSender, inEvent) {
    	var r = this.fileFilterList[inEvent.index];
    	if(r){
    		this.$.file.setContent(r.n);
    	}
    	return true;

	},

	selectItem: function(inSender, inEvent) {
    	var r = this.fileFilterList[inEvent.index];
    	if(r) {
    		enyo.Signals.send('onFileSelected', {file: r.d + '/' + r.n, name: r.n});
    	}
	},

	filterInputChange: function() {
       enyo.job("filterChange", enyo.bind(this, "filterChange"), 400);
       return true;
	},

	filterChange: function() {
		var filterString = this.$.filterField.getValue();

		if(filterString) {
			var subset = [];
			filterString = filterString.toLowerCase();

			//this.log("Filter String: " + filterString);

			var listItems = this.fileList;

			var i = 0;
    		while (i < listItems.length) {
    			// Filter by product discription
	        	if (listItems[i].d.toLowerCase().indexOf(filterString) >= 0) {
	        		//this.log(listItems[i].d);
	            	subset.push(listItems[i]);
	        	} else if (listItems[i].n.toLowerCase().indexOf(filterString) >= 0) {
	        	// Filter by merchant
	            	subset.push(listItems[i]);
	        	}
	        	i++;
    		}
			//this.log(subset);
    		this.fileFilterList = subset;
    		this.$.list.setCount(this.fileFilterList.length);
    		this.$.list.reset();

		} else {
			this.fileFilterList = this.fileList;
			this.$.list.setCount(this.fileFilterList.length);
			this.$.list.reset();
		}
		this.$.list.render();
	},

	resetFilter: function() {
		this.fileFilterList = this.fileList;
		this.$.list.render();
		return true;
	}

});


