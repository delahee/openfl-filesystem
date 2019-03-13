package openfl.filesystem;

using StringTools;

@:allow( openfl.filesystem.FileStream )
class File extends openfl.net.FileReference {
	
	//public
	public var absolutePath(get,null):String;
	public var exists(get, null):Bool;
	public var isDirectory(get, null):Bool;
	public var nativePath( get, null ) : String;
	public var url( get, null ):String;
	
	//////////////////////////////public statics
	//public static var applicationDirectory : File = new File(lime.system.System.applicationDirectory);
	//public static var applicationStorageDirectory:File = new File(lime.system.System.applicationStorageDirectory);
		
	static var __isInit = false;
	public static var applicationDirectory : File = null;
	public static var applicationStorageDirectory:File = null;
		
	#if switch
	var protocol : String = null;
	#end
	
	public function new( ?path:String
		#if switch
		, ?proto:String 
		#end
	)	{
		super();
		
		#if switch
		protocol = proto;
		if (protocol == null ){
			protocol = "rom:/";
		}
		#end
		
		trace("File::new File "+path);
		this.__path = path;
		
		//happens with "empty" constructor invocation
		if ( path == "" ) return;
		#if switch
		if ( path == "rom:/" ) return;
		if ( path == "save:/" ) return;
		#end
		
		normalize();
		
		#if !switch //does not work on switch
		var fileInfo = sys.FileSystem.stat(__path);
		if( fileInfo!=null){
			creationDate = fileInfo.ctime;
			modificationDate = fileInfo.mtime;
			size = fileInfo.size;
			type = "." + haxe.io.Path.extension(__path);
		}
		#else //acquire size
		__update(null);
		#end
	}
	
	static var _ : Dynamic = {
		#if console
			#if debug 
			trace("static init called deferred");
			#end
			haxe.Timer.delay( staticInit, 1 );
		#else 
			#if debug 
			trace("static init called direct");
			#end
			staticInit();	
		#end
		
		null;
	}
	
	static function __rawDir( path:String ){
		var f = new File("");
		f.__path = path;
		#if switch
		f.protocol = "";
		#end
		
		if ( f.__path == null ) f.__path = "";
		if( sep == "/" )  f.__path = f.__path.replace("\\", sep);
		if ( sep == "\\" ) f.__path = f.__path.replace("/", sep);
		
		if ( f.__path.endsWith(sep))
			f.__path += sep;
		f.isDirectory = true;
			
		return f;
	}
	
	#if cpp
	public static function initStorageDir(){
		//this call breaks on switch because it invokes profile logic
		applicationStorageDirectory = __rawDir(lime.system.System.applicationStorageDirectory);
	}
	#end
	
	static function staticInit(){//do not call isDirectory within here
		if ( !__isInit ){
			//#if debug
			//trace("File::StaticInit");
			//#end
			__isInit = true;
			applicationDirectory = __rawDir(lime.system.System.applicationDirectory);
			
			#if !switch
			//this call breaks on switch because it invokes profile logic
			applicationStorageDirectory = __rawDir(lime.system.System.applicationStorageDirectory);
			#end
		}
	}
	
	function normalize(){
		if ( __path == null ) return;
		
		if( sep == "/" )  __path = __path.replace("\\", sep);
		if( sep == "\\" ) __path = __path.replace("/", sep);
		
		if ( isDirectory ){
			if ( __path.charCodeAt(  __path.length - 1 ) != sep.charCodeAt(0) )
				__path = __path + sep;
		}
	}
	
	public function createDirectory(){
		sys.FileSystem.createDirectory( nativePath );
	}
	
	public function deleteDirectory(deleteDirectoryContents:Bool = false){
		if ( deleteDirectoryContents ){
			for ( f in getDirectoryListing() )
				f.deleteDirectory(deleteDirectoryContents);
		}
		sys.FileSystem.deleteDirectory( nativePath );
	}
	
	public function getDirectoryListing() : Array<File>{
		//#if debug trace("getDirectoryListing "+getOSPath()); #end
		if ( __path == null ){
			//#if debug trace("path is empy"); #end
			return [];
		}
		if ( !isDirectory ){
			//#if debug trace("not a dir"); #end
			return [];
		}
		var dirs = sys.FileSystem.readDirectory(getOSPath());
		if ( dirs == null ) return [];
		
		//#if debug trace("iterating"); #end
		return dirs.map( function(path) return resolvePath(path) );
	}
	
	public function get_absolutePath():String{
		return sys.FileSystem.absolutePath( nativePath );
	}
	
	//todo test
	public function deleteFile(){
		sys.FileSystem.deleteFile( nativePath);
	}
	
	//todo test
	public function deleteFileAsync(){
		#if !cpp
		sys.FileSystem.deleteFile( nativePath);
		#else 
		var path = nativePath;
		cpp.vm.Thread.create(function(){
			sys.FileSystem.deleteFile( path );
		});
		#end
	}
	
	public function resolvePath(path:String) : File {
		//if native path is a dir, it has a trailing slash
		return new File( nativePath + path);
	}
	

	/**
	 * Could setup a handler ?
	 */
	public function openWithDefaultApplication(){
		throw "[openWithDefaultApplication]not implemented";
	}
	
	
		
	public function browseForOpen(hint:String, filters : Array<Dynamic> ){
		throw "[browseForOpen]not implemented";
	}
	
	public function browseForDirectory(hint:String){
		throw "[browseForDirectory]not implemented";
	}
	
	//////////////////////////////private
	function get_nativePath() return __path;
	function get_url() return "file:///" + nativePath;
	
	public function getOSPath(){
		#if switch
			if( protocol!=null&&protocol.length>0)
				return protocol + __path;
			else 
				return __path;
		#else 
			return __path;
		#end
	}
	
	function get_exists():Bool{
		return sys.FileSystem.exists( getOSPath() );
	}
	
	function get_isDirectory(){
		#if switch 
		if ( nativePath == "rom://") return true;
		if ( nativePath == "save://") return true;
		#end
		
		return sys.FileSystem.isDirectory( getOSPath() );
	}
	
	function __update( ?fs : openfl.filesystem.FileStream ){
		#if !switch 
		var fileInfo = sys.FileSystem.stat( getOSPath() );
		if( fileInfo!=null){
			creationDate = fileInfo.ctime;
			modificationDate = fileInfo.mtime;
			size = fileInfo.size;
			type = "." + haxe.io.Path.extension( getOSPath() );
		}
		#else
		
		if ( isDirectory ) return;
		
		if( fs !=null)
			size = fs.size;
		else {
			var f = new FileStream();
			if( exists ){
				f.open(this, READ );
				size = f.size;
				f.close();
			}
		}
		#end
	}
	
	public static inline var sep = {
		#if windows
		"\\";
		#else 
		"/";
		#end
	}
	
	override function toString(){
		return "[Object File __path:" + nativePath +"]";
	}
	
	function dumpStats(){
		var fileInfo = sys.FileSystem.stat( getOSPath() );
		if ( fileInfo != null){
			trace("data for " + getOSPath());
			trace( fileInfo.ctime );
			trace( fileInfo.mtime );
			trace( fileInfo.size );
		}
	}

	
	
	
}
