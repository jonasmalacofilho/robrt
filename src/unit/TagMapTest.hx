package unit;

import robrt.TagMap;
import utest.Assert;

class TagMapTest extends utest.Test {
	public function test_000_basic()
	{
		var t = new TagMap();
		t["foo"] = "Bar";

		Assert.isTrue(t.exists("foo"));
		Assert.isTrue(t.exists("foo_lc"));
		Assert.equals("Bar", t["foo"]);
		Assert.equals("bar", t["foo_lc"]);

		Assert.isFalse(t.exists("foo_bar"));
		Assert.isNull(t["foo_bar"]);
	}
}

