package robrt;

@:forward
abstract TagMap(haxe.ds.StringMap<String>) from haxe.ds.StringMap<String> {
	function baseKey(key:String, suffix:String):String
	{
		if (!StringTools.endsWith(key, suffix)) return null;
		return key.substr(0, key.length - suffix.length);
	}

	function findBaseKey(key:String)
	{
		for (suffix in ["", "_lc"]) {
			var bkey = baseKey(key, suffix);
			if (bkey == null) continue;
			if (this.exists(bkey))
				return { key : bkey, suffix : suffix };
		}
		return null;
	}

	public function exists(key:String)
	{
		return findBaseKey(key) != null;
	}

	@:arrayAccess public function get(key:String)
	{
		var bkey = findBaseKey(key);
		if (bkey == null) return null;
		var val = this.get(bkey.key);
		return switch bkey.suffix {
		case "_lc": val.toLowerCase();
		case _: val;
		}
	}

	@:arrayAccess public function set(key:String, val:String)
		this.set(key, val);

	public function new()
		this = new haxe.ds.StringMap();
}

