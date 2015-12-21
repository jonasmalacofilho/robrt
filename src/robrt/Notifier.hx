package robrt;

import robrt.Event;
import robrt.server.ServerConfig;
import js.node.*;

interface Notifier {
	public function notify(event:Event, cb:js.Error->Notifier->Void):Void;
}

private class BaseNotifier implements Notifier {
	var repo:Repository;
	var base:{ branch:String, commit:String };
	var pr:Null<{ number:Int, commit:String }>;

	var tags:Map<String,String>;
	var customPayload:Null<CustomPayload>;

	function expand(p:Dynamic):Dynamic
	{
		return switch Type.typeof(p) {
		case TNull, TInt, TFloat, TBool: p;
		case TClass(c) if (Type.getClassName(c) == "String"):
			~/\$([a-z_]+)/g.map(p, function (r) {
				var key = r.matched(1);
				if (tags.exists(key))
					return tags[key];
				else
					return r.matched(0);
			});
		case TClass(c) if (Type.getClassName(c) == "Array"):
			[ for (i in (p:Array<Dynamic>)) expand(i) ];
		case TObject:
			var q:Dynamic = {};
			for (f in Reflect.fields(p))
				Reflect.setField(q, expand(f), expand(Reflect.field(p, f)));
			q;
		case _:
			throw 'Unexpected $p';
		}
	}

	function getPayload(isExport, isSuccess):Null<Dynamic>
	{
		if (customPayload == null) return null;
		var a = pr != null ? customPayload.pull_requests : customPayload.branches;
		if (a == null) return null;
		var b = isExport ? a.export : a.build;
		if (b == null) return null;
		var c = isSuccess ? b.success : b.failure;
		return expand(c);
	}

	public function notify(event:Event, cb:js.Error->Notifier->Void)
	{
		cb(new js.Error("Not implemented"), null);
	}

	public function new(repo, base, pr, tags, customPayload)
	{
		this.repo = repo;
		this.base = base;
		this.pr = pr;
		this.tags = tags;
		this.customPayload = customPayload;
	}
}

class SlackNotifier extends BaseNotifier {
	var url:String;

	function defaultText(prefix, msg)
	{
		msg = msg != null ? 'msg=$msg' : "";
		var keys = [ for (k in tags.keys()) k ];
		keys.sort(Reflect.compare);
		var props = [ for (k in keys) '$k=${tags[k]}' ].join(" ");
		return { text : '$prefix $msg $props' };

	}

	override public function notify(event:Event, cb:js.Error->Notifier->Void)
	{
		var p = switch event {
		case ENoBuild(_), ENoExport(_): null;
		case EBuildFailure(msg):
			var c = getPayload(false, false);
			if (c == null) c = defaultText("Build: FAILED", msg);
			c;
		case EBuildSuccess(msg):
			var c = getPayload(false, true);
			if (c == null) c = defaultText("Build: succeeded", msg);
			c;
		case EExportFailure(msg):
			var c = getPayload(true, false);
			if (c == null) c = defaultText("Export: FAILED", msg);
			c;
		case EExportSuccess(msg):
			var c = getPayload(true, true);
			if (c == null) c = defaultText("Export: succeeded", msg);
			c;
		}
		var _url = Url.parse(url);
		var opts:js.node.Http.HttpRequestOptions = {
			hostname : _url.hostname,
			path : _url.path,
			protocol : _url.protocol,
			port : 443,
			method : "POST"
		}
		function onRes(res:js.node.http.IncomingMessage) {
			if (res.statusCode == 200) {
				cb(null, null);
			} else {
				cb(new js.Error('bad status from slack: ${res.statusCode}'), this);
			}
			res.resume();
		}
		var req = Https.request(untyped opts, onRes);  // FIXME remove untyped
		req.end(haxe.Json.stringify(p));
	}

	public function new(url, repo, base, pr, tags, customPayload)
	{
		super(repo, base, pr, tags, customPayload);
		if (url == null) throw "Slack requires an url";
		this.url = url;
	}
}

class NotifierHub extends BaseNotifier {
	var notifiers:Array<{ name:String, notifier:Notifier }>;

	function shouldSend(event:Event, name:String)
	{
		return switch event {
		case ENoBuild(_), ENoExport(_):
			false;
		case EBuildFailure(_), EBuildSuccess(_):
			if (repo.build_options == null || repo.build_options.notify == null)
				return false;
			var h = Lambda.find(repo.build_options.notify, function (h) return h.target == name);
			if (h == null)
				return false;
			var t = event.match(EBuildSuccess(_)) ? success : failure;
			h.events == null || Lambda.has(h.events, t);
		case EExportFailure(_), EExportSuccess(_):
			if (repo.export_options == null || repo.export_options.notify == null)
				return false;
			var h = Lambda.find(repo.export_options.notify, function (h) return h.target == name);
			if (h == null)
				return false;
			var t = event.match(EExportSuccess(_)) ? success : failure;
			h.events == null || Lambda.has(h.events, t);
		}
	}

	override public function notify(event:Event, cb:js.Error->Notifier->Void)
	{
		for (n in notifiers)
			if (shouldSend(event, n.name))
				n.notifier.notify(event, cb);
	}

	public function new(tags, repo, base, ?pr, ?notifiers)
	{
		super(repo, base, pr, tags, null);

		if (notifiers != null) {
			this.notifiers = notifiers;
		} else if (repo.notification_targets != null) {
			this.notifiers = [];
			for (t in repo.notification_targets) {
				var name = t.name != null ? t.name : t.type;
				var n:{ name:String, notifier:Notifier } = switch t.type {
				case slack:
					{ name : name, notifier : new SlackNotifier(t.url, repo, base, pr, tags, t.payload) };
				case github:  // TODO
					null;
				}
				if (n != null)
					this.notifiers.push(n);
			}
		} else {
			this.notifiers = [];
		}
	}
}

