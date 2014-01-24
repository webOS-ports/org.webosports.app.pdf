var PDFFileScannerService = function() {
}

PDFFileScannerService.prototype.run = function(future) {
    var dir = this.controller.args.dir || '/media/internal';
	findPDFFiles(dir, future);
}


function findPDFFiles(dir, future){
    var exec  = IMPORTS.require('child_process').exec;
    var path =  IMPORTS.require('path');

	var child = exec('/usr/bin/find ' + dir + ' -type f -name \*.pdf -maxdepth 2', 
	  function (error, stdout, stderr) {
	    if (error !== null) {
	      console.log('exec error: ' + error);
	    }
	    var code = 0;
	    if(error){
	    	code = error.code || -1;
	    	future.result = {code: code};	
	    } else{
	    	var ff = stdout.split('\n');
	    	var length = ff.length;
	    	var fileList = [];
	    	for(var i=0; i<length; i++) {
	    		var f = ff[i];
	    		var d = path.dirname(f);
	    		var n = path.basename(f);
	    		fileList.push({d: d, n: n});
	    	}

	    	future.result = {code: code, files: fileList};	
	    }
	    
	});
}
