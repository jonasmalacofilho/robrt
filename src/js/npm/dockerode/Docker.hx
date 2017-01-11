package js.npm.dockerode;

import js.node.Buffer;
import js.node.stream.*;
import js.Error;

extern class Modem {
	function demuxStream(stream:Readable.IReadable, stdout:Writable.IWritable, stderr:Writable.IWritable):Void;
}

extern class Container {
	var modem:Modem;
	var id:String;

	@:overload(function(opts:{ stream:Bool, stdin:Bool }, callback:Error->Writable<Dynamic>->Void):Void {})
	function attach(opts:{ stream:Bool, stdout:Bool, stderr:Bool }, callback:Error->Readable<Dynamic>->Void):Void;

	function start(callback:Error->String->Void):Void;

	function inspect(callback:Error->String->Void):Void;

	@:overload(function(callback:Error->Dynamic->Void):Void {})
	function stop(opts:{ ?t:Int }, callback:Error->Dynamic->Void):Void;

	@:overload(function(callback:Error->Dynamic->Void):Void {})
	function kill(opts:{ ?signal:String }, callback:Error->Dynamic->Void):Void;
}

@:jsRequire("dockerode")
@:native("Docker")
extern class Docker {
	@:selfCall
	function new(?opts:js.npm.dockerModem.Options);

	// TODO type opts and Readable type paramenter
	@:overload(function(file:Buffer, opts:Dynamic, callback:Error->String->Void):Void {})
	@:overload(function(filename:String, opts:Dynamic, callback:Error->Readable<Dynamic>->Void):Void {})
	@:overload(function(filename:String, opts:Dynamic, callback:Error->String->Void):Void {})
	function buildImage(file:Buffer, opts:Dynamic, callback:Error->Readable<Dynamic>->Void):Void;

	// TODO type opts
	function createContainer(opts:Dynamic, callback:Error->Container->Void):Void;
}

