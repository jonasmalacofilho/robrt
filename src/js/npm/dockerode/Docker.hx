package js.npm.dockerode;

import js.node.Buffer;
import js.Error;

@:jsRequire("dockerode")
@:native("Container")
extern class Container {
}

@:jsRequire("dockerode")
@:native("Docker")
extern class Docker {
	@:selfCall
	function new(?opts:js.npm.dockerModem.Options);

	@:overload(function(file:Buffer, opts:Dynamic, callback:Error->String->Void):Void {})
	@:overload(function(filename:String, opts:Dynamic, callback:Error->Buffer->Void):Void {})
	@:overload(function(filename:String, opts:Dynamic, callback:Error->String->Void):Void {})
	function buildImage(file:Buffer, opts:Dynamic, callback:Error->Buffer->Void):Void;

	function createContainer(opts:Dynamic, callback:Error->Container->Void):Void;
}

