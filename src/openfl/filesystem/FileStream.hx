package openfl.filesystem;

using StringTools;

@:allow( openfl.filesystem.File )
class FileStream{
	/////////////private
	var fdesc : openfl.filesystem.File;
	var input : sys.io.FileInput;
	var output : sys.io.FileOutput;
	var mode : FileMode;
	
	/////////////public
	public var bytesAvailable( get, null) : UInt;
	public var size(get, null): UInt;
	
	public inline function new( ){ }
	
	public function open(f : openfl.filesystem.File, mode:FileMode){
		this.mode = mode;
		fdesc = f;
		switch(mode){
			case READ:
				try{
					input = sys.io.File.read(f.getOSPath(), true);
				}catch ( d:Dynamic ){
					throw new openfl.errors.IOError("No such file "+f.getOSPath());
				}
				
				//#if debug
				//fdesc.dumpStats();
				//#end
				
			case WRITE:
				
				fdesc._createDirectoryWithoutCommit();
				
				try{
					output = sys.io.File.write(f.getOSPath(), true);
				}catch ( d:Dynamic ){
					#if debug trace("fs::exception::"+d); #end
					throw new openfl.errors.IOError("Unable to open file "+f.getOSPath());
				}
				
				//#if debug
				//fdesc.dumpStats();
				//#end
				
			case APPEND:
				try{
					output = sys.io.File.append(f.getOSPath(), true);
					output.seek( 0, sys.io.FileSeek.SeekEnd );
				}catch ( d:Dynamic ){
					throw new openfl.errors.IOError("No such file " +f.getOSPath());
				}
				
			case UPDATE:
				// should probably open a read and append desc ?
				throw "not implemented";
		}
	}
	
	public function close(){
		if (input!=null) input.close();
		if (output != null) {
			output.flush();
			output.close();
		}
		
		#if switch
		if ( output!=null && fdesc.protocol != null && fdesc.protocol.startsWith( "save:" )){
			var committed = lime.console.nswitch.SaveData.commit();
			#if debug
			trace("NSwitch:Commit! "+committed+" > "+fdesc.getOSPath());
			#end
		}
		#end
		
		//invalid any r/w ops
		input = null;
		output = null;
	}
	
	public function readUTFBytes(len : UInt) : String {
		if ( input == null) throw new openfl.errors.IOError("File is not opened for read operations");
		
		var rem = get_bytesAvailable();
		
		if ( rem < len ) throw new openfl.errors.EOFError ("Eof encountered");
		var b = input.read(len);
		return b.toString();
	}
	
	public function readBytes(ba:openfl.utils.ByteArray, offset:UInt=0, length:UInt=0){
		if ( input == null) throw new openfl.errors.IOError("File is not opened for read operations");
		
		if ( offset >= 0 ) advance(offset);
		var rem = get_bytesAvailable();
		if ( length == 0 ) length = rem;
		
		
		if ( rem < length ) throw new openfl.errors.EOFError ("File is not opened for read operations");
		
		//#if debug trace("tasked to read "+length); #end
		var b = input.read(length);
		//#if debug  trace("extracted " + b.length); #end
		var nba = openfl.utils.ByteArray.fromBytes( b );
		
		ba.writeBytes( nba );
		
		return ba;
	}
	
	public function writeBytes(ba:openfl.utils.ByteArray, offset : UInt = 0, length:UInt = 0) : Void {
		if ( output == null) throw new openfl.errors.IOError("File is not opened for write operations");
		
		if ( length == 0 ) length = ba.length;
		
		var written = output.writeBytes( ba, offset, length );
		
		@:privateAccess fdesc.__update(this);
		#if debug
		//trace("written " + written + " > "+length);
		#end
	}
	
	public function writeByte(value:Int):Void{
		if ( output == null) throw new openfl.errors.IOError("File is not opened for write operations");
		
		output.writeByte(value);
		
		@:privateAccess fdesc.__update(this);
		#if debug
		//trace("written 1");
		#end
	}
	
	/**
	 * TODO : determine value encoding and transliterate?
	 */
	public function writeUTFBytes(value:String){
		if ( output == null) throw new openfl.errors.IOError("File is not opened for write operations");
		var bytes = haxe.io.Bytes.ofString(value);
		var written = output.writeBytes( bytes, 0, bytes.length );
		
		@:privateAccess fdesc.__update(this);
		#if debug
		trace("written " + bytes.length);
		#end
	}
	
	/**
	 * TODO : determine value encoding and transliterate?
	 */
	public function writeUTF(value:String){
		if ( output == null) throw new openfl.errors.IOError("File is not opened for write operations");
		var bytes = haxe.io.Bytes.ofString(value);
		var written = output.writeBytes( bytes, 0, bytes.length );
		@:privateAccess fdesc.__update(this);
		
	}
	
	//////////////Private
	function get_bytesAvailable(){
		return get_size()-getCurrentPos();
	}
	
	/////////////private
	function get_size(){
		if ( input != null){
			var pos = getCurrentPos();
			input.seek( 0, sys.io.FileSeek.SeekEnd );
			var lsize = input.tell();
			input.seek( pos, sys.io.FileSeek.SeekBegin );
			return lsize;
		}
		
		if ( output != null){
			var pos = getCurrentPos();
			output.seek( 0, sys.io.FileSeek.SeekEnd );
			var lsize = output.tell();
			output.seek( pos, sys.io.FileSeek.SeekBegin );
			return lsize;
		}
		return 0;
	}
	
	function getCurrentPos():Int{
		if ( input != null )
			return input.tell();
			
		if ( output != null )
			return output.tell();
		
		return 0;
	}
	
	function advance(val : Int){
		if ( input != null )
			input.seek( val, sys.io.FileSeek.SeekCur );
	}
	
}

