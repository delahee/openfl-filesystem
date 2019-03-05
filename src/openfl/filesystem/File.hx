package openfl.filesystem;

#if !sys
	#error("Does not support non sys compatible targets ")
#end

class File extends openfl.net.FileReference {
	
	//public
	public var absolutePath(get,null):String;
	public var exists(get, null):Bool;
	public var isDirectory(get, null):Bool;
	public var nativePath( get, null ) : String;
	public var url( get, null ):String;
	
	public function new( ?path:String )	{
		super();
		this.__path = path;
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
	
	public function get_absolutePath():String{
		return sys.FileSystem.absolutePath( nativePath );
	}

	/**
	 * Could setup a handler ?
	 */
	public function openWithDefaultApplication(){
		throw "[openWithDefaultApplication]not implemented";
	}
	
	//////////////////////////////public statics
	public static var applicationDirectory :File = 
		new File(lime.system.System.applicationDirectory);
	
	public static var applicationStorageDirectory:File = 
		new File(lime.system.System.applicationStorageDirectory);
		
	public function browseForOpen(hint:String, filters : Array<Dynamic> ){
		throw "[browseForOpen]not implemented";
	}
		
	//////////////////////////////private
	function get_nativePath() return __path;
	function get_url() return "file:///"+nativePath;
	
	function get_exists():Bool{
		try{
			var f = sys.io.File.read( nativePath, true );
			f.close();
			return true;
		}
		catch ( e : Dynamic){
			return false;
		}
		return false;
	}
	
	function get_isDirectory(){
		return sys.FileSystem.isDirectory( nativePath );
	}
	
	function getDirectoryListing() : Array<File>{
		return sys.FileSystem.readDirectory(nativePath).map( function(path) return new File(path));
	}
	
	
	
}
