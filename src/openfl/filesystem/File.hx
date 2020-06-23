package openfl.filesystem;

using StringTools;

//note flash native files do not have trailing slashes!
@:allow( openfl.filesystem.FileStream )
class File extends openfl.net.FileReference {
	
	//public
	public var absolutePath(get,null):String;
	public var exists(get, null):Bool;
	public var isDirectory(get, never ):Bool;
	public var nativePath( get, null ) : String;//nativePath does not incorporate protocol
	public var url( get, null ):String;
	public var parent( get, null) : File;
	
	//////////////////////////////public statics
	//public static var applicationDirectory : File = new File(lime.system.System.applicationDirectory);
	//public static var applicationStorageDirectory:File = new File(lime.system.System.applicationStorageDirectory);
		
	static var __isInit = false;
	public static var applicationDirectory : File = null;
	public static var applicationStorageDirectory:File = null;
	public static var separator : String = null;
		
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
		
		this.__path = path;
		
		//happens with "empty" constructor invocation
		if ( __path == "" ) return;
		#if switch
		if ( __path == "rom:/" ) return;
		if ( __path == "save:/" ) return;
		if ( __path.startsWith(protocol) )
			__path = __path.replace(protocol, "");
		#end
		
		normalize();
		
		#if debug
		//trace("File::new File " + __path);
		#end
		
		#if !switch //does not work on switch by N. design
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
			//trace("static init called deferred");
			#end
			haxe.Timer.delay( staticInit, 1 );
		#else 
			#if debug 
			//trace("static init called direct");
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
		if( separator == "/" )  f.__path = f.__path.replace("\\", separator);
		if( separator == "\\" ) f.__path = f.__path.replace("/", separator);
		
		if ( f.__path.endsWith(separator))
			f.__path += separator;
			
		return f;
	}
	
	#if cpp
	public static function initStorageDir(){
		//this call breaks on switch because it invokes profile logic
		applicationStorageDirectory = __rawDir(lime.system.System.applicationStorageDirectory);
		
		#if switch
		applicationStorageDirectory.__path = applicationStorageDirectory.__path.replace("save:/", "");
		applicationStorageDirectory.protocol = "save:/";
		#end
	}
	#end
	
	static function staticInit(){//do not call isDirectory within here
		if ( !__isInit ){
			#if windows
			separator = "\\";
			#else 
			separator = "/";
			#end
			
			__isInit = true;
			applicationDirectory = __rawDir(lime.system.System.applicationDirectory);
			
			#if !switch
			//this call breaks on switch because it invokes profile logic
			initStorageDir();
			#end
			
			
		}
	}
	
	function isProtocol(){
		var nativePath = get_nativePath();
		if ( nativePath.endsWith(":") ) return true;//this is a protocol
		if ( nativePath.endsWith(":/") ) return true;//this is a protocol
		if ( nativePath.endsWith("://") ) return true;//this is a protocol
		return false;
	}
	
	//returns the base directory without the protocol...
	function getBaseDirectory(){
		var nativePath = get_nativePath();
		if ( nativePath == separator ) return nativePath;
		if ( isProtocol() ) return nativePath;//this is a protocol
		
		var ps = nativePath.split(separator);
		ps.pop();
		return ps.join(separator);
	}
	
	function get_parent() : File {
		if ( isDirectory ){
			return resolvePath("..");
		}
		else {
			return new File( getBaseDirectory() #if switch, protocol #end);
		}
	}
	
	function normalize(){
		if ( __path == null ) return;
		
		if( separator == "/" )  __path = __path.replace("\\", separator);
		if( separator == "\\" ) __path = __path.replace("/", separator);
		
		if ( isDirectory ){
			//#if debug
			//trace( getOSPath()+" is dir?");
			//#end
			if ( __path.charCodeAt(  __path.length - 1 ) == separator.charCodeAt(0) )
				__path = __path.substr(0,__path.length-1);
		}
	}
	
	public function createDirectory(){
		var folder = #if switch protocol + #end getBaseDirectory();
		
		if ( folder == "") return;
		if ( folder == "/") return;
		if ( folder == separator) return;
		
		#if debug
		//trace("creating " + folder);
		#end
		
		sys.FileSystem.createDirectory( folder );
		
		#if switch
		commit();
		#end
	}
	
	#if switch
	function commit(){
		if ( protocol != null && protocol.startsWith( "save:" )){
			var committed = lime.console.nswitch.SaveData.commit();
		}
	}
	#end
	
	function _createDirectoryWithoutCommit(){
		var folder = #if switch protocol + #end getBaseDirectory();
		
		if ( folder == "") return;
		if ( folder == "/") return;
		if ( folder == separator) return;
		
		#if debug
		trace("trying to create :" + folder);
		#end
		sys.FileSystem.createDirectory( folder );
	}
	
	public function deleteDirectory(deleteDirectoryContents:Bool = false){
		if ( deleteDirectoryContents ){
			for ( f in getDirectoryListing() )
				f.deleteDirectory(deleteDirectoryContents);
		}
		sys.FileSystem.deleteDirectory( getOSPath() );
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
		return sys.FileSystem.absolutePath( getOSPath() );
	}
	
	public function deleteFile(){
		sys.FileSystem.deleteFile( getOSPath());
	}
	
	public function deleteFileAsync(){
		#if !cpp
		sys.FileSystem.deleteFile( getOSPath());
		#else 
		var path = getOSPath();
		cpp.vm.Thread.create(function(){
			sys.FileSystem.deleteFile( path );
		});
		#end
	}
	
	public function resolvePath(path:String) : File {
		var f = new File( nativePath + separator + path #if switch, protocol #end );
		return f;
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
	function get_url() return "file:///" + nativePath.replace("\\","/");
	
	public function getOSPath(){
		#if switch
			if( protocol!=null&&protocol.length>0&& !__path.startsWith(protocol))
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
		if ( isProtocol() ) return true;
		
		if ( !exists ) return false;
		
		if ( __path.endsWith( separator )) return true;
		
		return sys.FileSystem.isDirectory( getOSPath() );
	}
	
	function __update( ?fs : openfl.filesystem.FileStream ){
		#if !switch 
		//stat( ) does nt work on switch by N. design
		//could work in debug with filestampfordebug
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
	
	override function toString(){
		return "[Object File __path:" + nativePath +"]";
	}
	
	//stat( ) does nt work on switch by N design
	function dumpStats(){
		var fileInfo = sys.FileSystem.stat( getOSPath() );
		if ( fileInfo != null){
			//trace("data for " + getOSPath());
			trace( fileInfo.ctime );
			trace( fileInfo.mtime );
			trace( fileInfo.size );
		}
	}

	
	
	
}
