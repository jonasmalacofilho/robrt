class Version {
	static function getVersionNumber():String
	{
		var package_json = haxe.Json.parse(sys.io.File.getContent('package.json'));
		return 'v${package_json.version}';
	}

	static function describeCommit():String
	{
		var args = ['describe', '--abbrev=9', '--exclude=*', '--always', '--dirty'];
		var git_describe = new sys.io.Process('git', args);
		if (git_describe.exitCode() != 0) {
			throw('`git ${args.join(' ')}` failed: ' + git_describe.stderr.readAll().toString());
		}
		return git_describe.stdout.readLine();
	}

	public static macro function getProject():haxe.macro.Expr
	{
		return macro $v{getVersionNumber()} + '+' + $v{describeCommit()};
	}

	public static macro function getHaxe():haxe.macro.Expr
	{
		var args = ['-version'];
		var proc_haxe_version = new sys.io.Process('haxe', args);
		if (proc_haxe_version.exitCode() != 0) {
			throw('`haxe ${args.join(' ')}` failed: ' + proc_haxe_version.stderr.readAll().toString());
		}
		var ver = 'v' + proc_haxe_version.stdout.readLine();
		return macro $v{ver};
	}
}

