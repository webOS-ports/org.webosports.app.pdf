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
				{layoutKind: "FittableRowsLayout", components: [
					{name: "file", style: "margin-left: 10px; font-weight: bolder;", fit: true},	
					{layoutKind: "FittableColumnsLayout", components: [
						{name: "modified", style: "margin-left: 10px;"},
						{name: "size", style: "margin-left: 10px;"}	
					]}
					
				]}
				
			]},
        ]},
        { name: "mediaPermisionService",
          kind: "enyo.PalmService",
          service: "palm://com.palm.mediapermissions",
          method: "request",
          subscribe: false,
          onComplete: "mediaPermisionComplete"
        },
        { name: "fileScannerService",
          kind: "enyo.PalmService",
          service: "palm://com.palm.db",
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

	askPermision: function() {
		enyo.log("Platform: " + JSON.stringify(enyo.platform));

		if(typeof PalmServiceBridge === 'undefined') {
 			enyo.log("Not a WebOS Platform , using mock service results instead");

			this.mediaPermisionComplete({},	
				{data: {
						returnValue: true, 
						isAllowed: true
						}
				}
			);	
		} else{
			this.$.mediaPermisionService.send({"query": { "rights": { "read": ["com.palm.media.misc.file:1"] } } });						
		}
	},

	scanFiles: function() {
		enyo.log("Platform: " + JSON.stringify(enyo.platform));

		if(typeof PalmServiceBridge === 'undefined') {
 			enyo.log("Not a WebOS Platform , using mock service results instead");

			this.fileScanComplete({},	
				{data: {
						returnValue: true,
						results: [ { name: "helloworld.pdf", path: "assets/helloworld.pdf", size: 678, modifiedtime: 1388620800, d: "Description of Hello World file", n: "Merchant?" } ]
						}
				}
			);	
		} else{
			this.$.fileScannerService.send({"query":{"from":"com.palm.media.misc.file:1","where":[{"prop":"extension","op":"=","val":"pdf"}]}});						
		}

	},

	/*
	 * If we are granted permision, we should get
	 * 
	 * {"returnValue":true,"isAllowed":true}
	 */
	mediaPermisionComplete: function(inSender, inEvent) {
		var result = inEvent.data;
		enyo.log(JSON.stringify(result));
		if(!result.returnValue === true || !result.isAllowed === true){
			enyo.log("Failed to get permision to read media Database: " + JSON.stringify(result));
			enyo.Signals.send('onError', "Access denieid to media Database");	
		}
		this.scanFiles();
	},

	fileScanComplete: function(inSender, inEvent){
		var result = inEvent.data;
		enyo.log(JSON.stringify(result));
		this.$.busyPopup.hide();
		if(result.returnValue === true) {
			this.fileList = result.results;	
		} else {
			enyo.log("Failed to find PDF Files: " + JSON.stringify(result));
			enyo.Signals.send('onError', "Failed to find PDF Files");
		}

		this.fileFilterList = this.fileList;
		this.$.list.setCount(this.fileList.length);
		this.$.list.reset();
		
	},

	setupItem:  function(inSender, inEvent) {
    	var r = this.fileFilterList[inEvent.index];
    	if(r){
    		this.$.file.setContent(r.name);
    		this.$.size.setContent(this.formatFileSize(r.size));
    		this.$.modified.setContent(this.formatModifiedTime(r.modifiedTime));
    	}
    	return true;

	},

	formatModifiedTime: function(modifiedTime) {
		if(modifiedTime) {
			try {
				var d = new Date(modifiedTime*1000);
				return d.getDate() + '/' + (d.getMonth() + 1) + '/' + d.getFullYear();	
			}catch(err) {
				enyo.log(JSON.stringify(err));
				return '';
			}
		} else {
			return '';
		}
	},

	formatFileSize: function(bytes) {
		try {
			var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
			if (bytes == 0) {
				return '0 Byte';
			}
			var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
			return Math.round(bytes / Math.pow(1024, i), 2) + ' ' + sizes[i];
		}catch(err) {
			enyo.log(JSON.stringify(err));
			return '';
		}
	},



	selectItem: function(inSender, inEvent) {
    	var r = this.fileFilterList[inEvent.index];
    	if(r) {
    		enyo.Signals.send('onFileSelected', {file: r.path, name: r.name});
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


