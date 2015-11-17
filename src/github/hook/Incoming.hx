package github.hook;

import neko.Web;
import haxe.crypto.*;
import haxe.io.Bytes;

import github.hook.Event;

typedef Delivery = {
	repository : BaseRepository,
	sender : User,
	event : Event
}

class Incoming {
	var event:String;
	var signature:String;
	var payload:String;

	public var delivery(default,null):String;

	function new(delivery, event, signature, payload)
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
		if (!StringTools.startsWith(signature, "sha1="))
			throw 'Unsupported hash algorithm in signature';
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

	public static function fromWeb()
	{
		// TODO check method==POST
		var delivery = Web.getClientHeader("X-Github-Delivery");
		var event = Web.getClientHeader("X-Github-Event");

		var signature = Web.getClientHeader("X-Hub-Signature").toLowerCase();
		// TODO deal with content-type==application/x-www-form-urlencoded
		var payload = Web.getPostData();

		return new Incoming(delivery, event, signature, payload);
	}
}

