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

				var scale = info.scale;
				var viewport = page.getViewport(scale);
				
				var canvas = document.getElementById('app_pdfViewer_canvas');
				var context = canvas.getContext('2d');
				canvas.height = viewport.height;
				canvas.width = viewport.width;
				
				page.render({canvasContext: context, viewport: viewport}).promise.then(function renderComplete(){
					enyo.Signals.send('onPageLoadEnd', {});
				});
				
			});
		}
	}

	
});
