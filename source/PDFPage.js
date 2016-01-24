enyo.kind({
	name: "PDFPage",
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
			enyo.log("renderPage: " + info.page);
			info.pdf.getPage(info.page).then(function drawPage(page) {


				var canvas = document.getElementById('app_pdfViewer_canvas');
				var context = canvas.getContext('2d');

				//enyo.log("Scale: " + info.scale);
				if(!info.scale) {

					if(!info.defaultScale) {
						// default scale  - show full page
						enyo.log("Calculating Default Scale");
						info.defaultScale = window.innerWidth / page.getViewport(1.0).width;		
					}
					info.scale = info.defaultScale;
					enyo.log("Using Default Scale: " + info.scale);
				}

				
				var viewport = page.getViewport(info.scale, info.rotation);

				//enyo.log("viewport: (" + viewport.height + "," + viewport.width + ")");
				
				canvas.height = viewport.height;
				canvas.width = viewport.width;
				
				page.render({canvasContext: context, viewport: viewport}).promise.then(function renderComplete(){
					enyo.Signals.send('onPageLoadEnd', {});
				});
				
			});
		}
	}

	
});
