package unit;

class Cross {
	static function main()
	{
		var run = new utest.Runner();
		run.addCase(new TagMapTest());

		utest.ui.Report.create(run);

		run.run();
	}
}

