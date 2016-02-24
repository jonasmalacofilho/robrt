package robrt;

@:forward
abstract TagMap(haxe.ds.StringMap<String>) from haxe.ds.StringMap<String> {
	function subkey(key:String, suffix:String):String
	{
		if (!StringTools.endsWith(key, suffix)) return null;
		return key.substr(0, key.length - suffix.length);
	}

	function findSubkey(key:String):String
	{
		if (this.exists(key)) return key;
		else if (this.exists(subkey(key, "_lc"))) return key + "_ic";
		else return null;
	}

	public function exists(key:String)
	{
		return findSubkey(key) != null;
	}

	@:arrayAccess public function get(key:String)
	{
		var skey = findSubkey(key);
		if (skey == null) return null;
		return this.get(skey);
	}

	@:arrayAccess public function set(key:String, val:String)
		this.set(key, val);

	public function new(map)
		this = map;
}

