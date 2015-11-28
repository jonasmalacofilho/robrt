package github.hook;

import github.hook.Event;
import haxe.crypto.*;
import haxe.io.Bytes;

typedef Delivery = {
	repository : BaseRepository,
	sender : User,
	event : Event
}

typedef Web = {
	function getClientHeader(name:String):String;
	function getMethod():String;
	function getPostData():String;
}

class Incoming {
	var event:String;
	var signature:String;
	var payload:String;

	public var delivery(default,null):String;

	function new(delivery, event, signature:Null<String>, payload)
	{
		this.delivery = delivery;
		this.event = event;
		this.signature = signature;
		this.payload = payload;
	}

	function safeCompare(a:String, b:String)
	{
		if (a.length != b.length)
			return false;
		var r = true;
		for (i in 0...a.length)
			if (StringTools.fastCodeAt(a, i) != StringTools.fastCodeAt(b, i))
				r = false;
		return r;
	}

	public function verify(secret:String)
	{
		trace(signature);
		if (signature == null || !StringTools.startsWith(signature, "sha1="))
			return false;
		var sig = signature.substr("sha1=".length);
		var hmac = new Hmac(SHA1).make(Bytes.ofString(secret), Bytes.ofString(payload));
		return safeCompare(hmac.toHex(), sig);
	}

	public function parse():Delivery
	{
		var data:Dynamic = haxe.Json.parse(payload);
		var event = switch (event) {
		case "ping": GitHubPing(data);  // TODO validate
		case "push": GitHubPush(data);  // TODO validate
		case "pull_request": GitHubPullRequest(data);  // TODO validate
		case _:
			throw 'Event $event not supported yet';
		}
		return {
			repository : data.repository,
			sender : data.sender,
			event : event
		}
	}

	public static function fromWeb(web:Web)
	{
		if (web.getMethod() != "POST")
			throw 'Method should be POST, not ${web.getMethod()}';
		
		var delivery = web.getClientHeader("X-Github-Delivery");
		var event = web.getClientHeader("X-Github-Event");
		var signature = web.getClientHeader("X-Hub-Signature");

		if (delivery == null || event == null)
			throw 'Missing one or more of required headers X-Github-Delivery and X-Github-Event';

		// TODO deal with content-type==application/x-www-form-urlencoded
		var contentType = web.getClientHeader("Content-Type");
		if (contentType != "application/json")
			throw 'Missing "Content-Type" header, or value other than "application/json" unsupported';

		var payload = web.getPostData();

		return new Incoming(delivery, event, signature != null ? signature.toLowerCase() : null, payload);
	}
}

