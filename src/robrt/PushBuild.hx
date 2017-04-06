package robrt;

import js.node.*;
import js.node.stream.*;
import js.npm.dockerode.Docker;
import robrt.Event;
import robrt.Notifier;
import robrt.Variables;
import robrt.repository.RepoConfig;
import robrt.server.BuildDir;
import robrt.server.ServerConfig;

class OutputStream extends Transform<OutputStream> {
	var listenFor:{ pattern:EReg, id:Int };
	var matchBuffer:String;

	public function new(listenFor)
	{
		super();
		this.listenFor = listenFor;
		matchBuffer = "";
	}

	override function _transform(chunk:Buffer, encoding:String, cb:js.Error->haxe.extern.EitherType<String,Buffer>->Void)
	{
		this.push(chunk);
		matchBuffer += chunk;
		while (listenFor.pattern.match(matchBuffer)) {
			matchBuffer = listenFor.pattern.matchedRight();
			if (listenFor.pattern.matched(1) == Std.string(listenFor.id)) {
				this.emit("cmd-finished", listenFor.pattern.matched(2));
				break;
			}
		}
		cb(null, null);
	}
}

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta("async"))
class PushBuild {
	var request:IncomingRequest;
	var repo:Repository;
	var base:{ branch:String, ?commit:String };
	var notifier:NotifierHub;

	var tags:TagMap;

	var buildDir:BuildDir;
	var repoConf:RepoConfig;
	var logOutput:js.node.fs.WriteStream;
	var docker:Docker;
	var container:{ container : Container, stdouts:Readable<Dynamic>, stdin:Writable<Dynamic> };

	function log(msg:Dynamic, ?events:Array<Event>, ?pos:haxe.PosInfos)
	{
		request.log(msg, pos);
		if (events == null || events.length == 0)
			return;
		for (e in events) {
			request.log('notify: $e');
			function fatal(err:js.Error, nn:Notifier) {
				if (err != null)
					log('notify: fatal failure(s) ($err)');
			}
			function retry(err:js.Error, nn:Notifier) {
				if (err == null)
					return;
				if (nn != null) {
					log('notify: failure(s) on first try, trying again ($err) in 30s');
					js.Node.setTimeout(nn.notify.bind(e, fatal), 30000);
				} else {
					fatal(err, nn);
				}
			}
			notifier.notify(e, retry);
		}
	}

	static function shEscape(s:String)
	{
		return "'" + s + "'";
	}

	function expandPath(path:String)
	{
		var gen = "";
		var pat = ~/\$([a-z_]+)/g;
		while (path.length > 0) {
			if (!pat.match(path)) {
				gen += path;
				break;
			}
			gen += pat.matchedLeft();
			var key = pat.matched(1);
			if (tags.exists(key)) {
				gen += tags[key];
			} else {
				log('ignoring tag $$$key');
				gen += pat.matched(0);
			}
			path = pat.matchedRight();
		}
		return gen;
	}

	function getBuildDir(baseBuildDir, id):BuildDir
	{
		var base = Path.join(expandPath(baseBuildDir), id);
		var dir =  {
			dir : {
				base : base,
				repository : Path.join(base, "repository"),
				to_export : Path.join(base, "to_export")
			},
			file : {
				docker_build : Path.join(base, "docker_image.tar"),
				robrt_build_log : Path.join(base, "robrt_build_log")
			}
		}
		try {
			// probably there's nothing to remove since base is constructed from id, but ...
			js.npm.Remove.removeSync(base, { ignoreMissing : true });
			// create necessary subdirectories
			js.npm.MkdirDashP.mkdirSync(dir.dir.base);
			js.npm.MkdirDashP.mkdirSync(dir.dir.to_export);
		} catch (e:Dynamic) {
			log('Warning: $e; kept going');
		}
		return dir;
	}

	// TODO handle submodules
	// TODO prevent git_terminal_prompt to /dev/tty (might be related to GIT_TERMINAL_PROMPT)
	@async function openRepo(fullName:String, dest:String, base:{ branch:String, ?commit:String }, ?pr:{ number:Int, commit:String }, ?token:String):Bool
	{
		var url = 'https://github.com/$fullName';
		// $token would sufice, but $token:$token prevents git from asking for a password on /dev/tty
		var authUrl = if (token == null) url else StringTools.replace(url, "https://", 'https://$token:$token@');

		// clone and checkout the specified commit
		// for homogeneity with `pr != null` reset the `base.branch` to `base.commit`
		// (this ensures that we're not building some more recent version of the branch by accident)
		var commands = [ 'git clone --quiet --branch ${shEscape(base.branch)} $authUrl $dest' ];  // TODO --depth 1
		if (base.commit != null) {
			// reset the `base.branch` to `base.commit`
			// (this ensures that we're not building some more recent version of the branch by accident)
			commands = commands.concat([
				'git -C $dest checkout --quiet --force ${base.commit}',  // TODO fallback because of --depth 1
				'git -C $dest reset --quiet --hard ${base.commit}'
			]);
		}
		// TODO log current head
		if (pr != null) {
			// fetch the pull request base and branch from the specified base commit
			// (this ensures that we're not building some more recent version of the PR by accident)
			commands = commands.concat([
				'git -C $dest fetch --quiet origin pull/${pr.number}/head',
				'git -C $dest branch --quiet pull/${pr.number}/head ${pr.commit}'
			]);
		}
		// cleanup the auth token
		if (token != null)
			commands.push('git -C $dest remote set-url origin $url');

		for (cmd in commands) {
			var err, stdout, stderr = @await ChildProcess.exec(cmd);
			if (err != null) {
				var msg = if (token == null) err.message else StringTools.replace(err.message, token, "******");
				log('ERR: $msg');
				return false;
			}
		}
		return true;
	}

	function readRepoConfig(repoDir:String):Null<RepoConfig>
	{
		// TODO make it async (requires fixed sync try/catch handling on haxe-continuation);
		// for this it is necessary to store context for Context.typeof or abandon that method
		// of choosing how to transform ETry expressions
		try {
			var p = Path.join(repoDir, ".robrt.json");
			if (!sys.FileSystem.exists(p))
				return {};
			var confData = Fs.readFileSync(p, "utf8");
			return haxe.Json.parse(confData);
		} catch (e:Dynamic) {
			return null;
		}
	}

	function copyFile(src:String, dst:String, cb:js.Error->Void)
	{
		var src = Fs.createReadStream(src);
		var dst = Fs.createWriteStream(dst);
		src.on("error", cb);
		dst.on("error", cb);
		dst.on("finish", cb.bind(null));
		src.pipe(dst);
	}

	@async function writeFile(dest:String, file:robrt.repository.File, repoDir:String)
	{
		var err;
		switch (file.type) {
		case InlineFile:
			err = @await Fs.writeFile(dest, file.data);
		case PathToFile:
			var src = Path.normalize(file.data);
			if (src.indexOf("..") > 0)
				return new js.Error('EVIL path: ${file.data} (normalizes to $src)');
			// TODO check for evil symlinks too
			err = @await copyFile(Path.join(repoDir, src), dest);
		}
		return err;
	}

	@async function prepareDockerBuild(opts:robrt.repository.PrepareOptions)
	{
		var dest = buildDir.file.docker_build;
		var tdest = dest + ".contents";
		var err = @await Fs.mkdir(tdest);
		if (err != null)
			return err;
		var err = @await writeFile(Path.join(tdest, "Dockerfile"), opts.dockerfile, buildDir.dir.repository);
		if (err != null)
			return err;

		var err, stdout, stderr = @await ChildProcess.exec('tar --create --file $dest --directory $tdest .');
		if (err != null)
			return err;
		return null;
	}

	/*
	Handle the build of a Docker Image.

	Monitor the progress, forward the output to the build log and call the
	callback with the appropriate result (error?).

	Implementation details:

	 - this is made to be compatible with the current log formats supported
	   by the log viewer
	 - the cmd number chosen cannot be negative (to break compatibility) or
	   zero (because it would conflict with the actual build), so we've
	   settled on the unsigned 2-byte number which has the same hexadecimal
	   representation as the desired negative number (i.e. -1 => 65535)
	*/
	function buildImage(image:String, opts:Dynamic, callback:js.Error->Void)
	{
		function cb(err, out:js.node.stream.Readable<Dynamic>) {
			if (err != null) {
				callback(err);
				return;
			}
			var buf = new StringBuf();
			out.on("data", function (chunk) buf.add(chunk) );
			out.on("error", callback);
			out.on("end",
				function () {
					var out = StringTools.trim(buf.toString()).split("\r\n");
					var res = new StringBuf();
					res.add("+ prepare: build docker image\n");
					res.add("robrt: started cmd <65535>\n");
					var err = null;
					for (r in out) {
						var r:{ ?stream:String, ?error:String } = haxe.Json.parse(r);
						if (r.error != null)
							err = r.error;
						if (r.stream == null)
							continue;
						res.add(r.stream);
					}
					var errCode = err == null ? "0" : err.substr(err.indexOf("returned a non-zero code: ") + 26);
					res.add('robrt: finished cmd <65535> with status <$errCode>\n');
					logOutput.write(res.toString(), function () callback(err == null ? null : new js.Error(err)) );
				});
		}
		docker.buildImage(image, opts, cb);
	}

	function fillEnv(env:Array<String>)
	{
		env.push('$Head=${base.branch}');
		env.push('$HeadCommit=${base.commit}');
		env.push('$IsPullRequest=0');
	}

	@async function prepareContainer(name:String, refresh:Bool)
	{
		if (name.toLowerCase() != name) {
			log("docker would have failed, container name must be lower case (apparently)");
			return null;
		}
			
		var err = @await prepareDockerBuild(repoConf.prepare);
		if (err != null) {
			log(err);
			return null;
		}

		var imageName = 'robrt-builds/$name:${request.buildId}';
		var err = @await buildImage(buildDir.file.docker_build, {
			t : imageName,
			q : true,
			rm : false,
			pull : refresh,
			nocache : refresh
		});
		if (err != null) {
			log(err);
			return null;
		}

		var repoDir = "/robrt/repository";
		var expDir = "/robrt/export";
		// TODO figure out how to escape vars to Docker; that's not documented anywhere : /
		var env = ['$RepoPath=$repoDir', '$OutPath=$expDir'];
		fillEnv(env);
		if (repo.build_options.env != null) {
			var export = repo.build_options.env;
			for (name in Reflect.fields(export))
				env.push('$name=${Reflect.field(export, name)}');
		}
		var err, container = @await docker.createContainer({
			Image : imageName,
			Env : env,
			Cmd : "bash",
			AttachStdin : true,
			AttachStdout : true,
			AttachStderr : true,
			OpenStdin : true,
			Tty : false,
			HostConfig : {
				Binds : [
					'${buildDir.dir.repository}:$repoDir',
					'${buildDir.dir.to_export}:$expDir',
				]
			}
		});
		if (err != null) {
			log(err);
			return null;
		}

		var oerr, stdouts = @await container.attach({ stream : true, stdout : true, stderr : true });
		if (oerr != null) {
			log(oerr);
			return null;
		}
		var ierr, stdin = @await container.attach({ stream : true, stdin : true });
		if (ierr != null) {
			log(ierr);
			return null;
		}

		return { container : container, stdouts : stdouts, stdin : stdin };
	}

	@async function prepareRepository()
	{
		log("cloning", [EOpeningRepo]);
		var cloned = @await openRepo(repo.full_name, buildDir.dir.repository, base, repo.oauth2_token);
		if (!cloned) {
			log("repository error", [ERepositoryError]);
			return false;
		}
		return true;
	}

	@async function prepareBuild()
	{
		var ok = @await prepareRepository();
		if (!ok)
			return 500;
		repoConf = readRepoConfig(buildDir.dir.repository);
		if (repoConf == null) {
			log("Invalid .robrt.json", [EInvalidRepoConf]);
			return 500;
		}
		if (Reflect.fields(repoConf).length == 0) {
			log("No .robrt.json", [ENoRepoConf]);
			return 200;
		}
		if (repoConf.prepare == null) {
			log("nothing to do; no 'prepare' in .robrt.json", [ENoRepoPrepare]);
			return 200;
		}

		log("preparing", [EPreparing]);
		container = @await prepareContainer(repo.full_name.toLowerCase(), false);
		if (container == null) {
			log("FAILED: could not create container", [EPrepareError]);
			return 500;
		}
		log('container is ${container.container.id}');
		return 0;
	}

	@async function build()
	{
		if (repoConf.build == null) {
			log("nothing to do; no 'build' in .robrt.json", [ENoRepoBuild]);
			return 200;
		}

		if (repoConf.build.cmds == null || repoConf.build.cmds.length == 0) {
			log("nothing to do; empty build command list .robrt.json", [ENoRepoBuild]);
			return 200;
		}

		log("building", [EBuilding]);
		var result = 0;

		// actual commands to execute are build from user specified
		// ones, but with some additional contextual information that
		// allows us to track each command start and finish
		var wcmds = [];
		for (id in 0...repoConf.build.cmds.length) {
			var scmd = haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(repoConf.build.cmds[id]));
			wcmds.push('echo "robrt: started cmd <$id>: $scmd: $$(date \'+%s.%N\')"; ${repoConf.build.cmds[id]}; echo "robrt: finished cmd <$id> with status <$$?>: $$(date \'+%s.%N\')"\n');
		}

		var buffer = "";
		var id = {
			pattern : ~/robrt: finished cmd <(\d+)> with status <(\d+)>(:.+)?\n/i,
			id : -1
		};

		var output = new OutputStream(id);
		output.pipe(logOutput);

		// to run a command, just write it to the container stdin
		function run() {
			id.id++;
			var cmd = repoConf.build.cmds[id.id];
			var wcmd = wcmds[id.id];
			log('running ${id.id}: $cmd');
			output.write('+ $cmd\n');  // TODO deprecated, remove
			container.stdin.write(wcmd);
		}

		// handle what to next after a command has finished
		// if all is well, just execute the next one; else (on error or
		// if there are no more commands to run) do something then stop
		// the container
		function finished(exit:Int) {
			log('cmd ${id.id} exited with status $exit');
			if (exit != 0) {
				log("ABORTING: non zero status", [EBuildFailure]);
				result = 500;
				// should ultimately result in a "end" event to stdouts
				container.container.kill(function (err, data) if (err != null) log('Warning: kill container error $err ($data)') );
			} else if (id.id + 1 < wcmds.length) {
				// run the next command
				run();
			} else {
				log("successful build, it seems", [EBuildSuccess]);
				// should ultimately result in a "end" event to stdouts
				container.container.stop({ t : 2 }, function (err, data) if (err != null) log('Warning: stop container error $err ($data)') );
			}
		}

		container.container.modem.demuxStream(container.stdouts, output, output);
		output.on("cmd-finished", finished);
		// TODO limit the maximum execution time of a container to something sensible

		log("spinning up container");
		var err, zzz = @await container.container.start();
		if (err != null) {
			log('error starting the container: $err', [EBuildError]);
			return 500;
		}

		log("executing commands");
		run();  // execute the first command
		@await container.stdouts.once("end");  // wait for the container to finish

		// TODO cleanup

		log("build successfull");
		return result;
	}

	function getExportPath()
		return repo.export_options.destination.branches;

	/*
	Export content and logs.

	Automatically figure out and handle if:

	 - export has been totally disabled on server config
	 - ref has been filtered out from exporting on server config
	 - build log export has disabled on server config
	 - content export has been disabled on server config
	 - content export has been disabled on repo .robrt.json
	 - content export has been disabled because the build has terminated with non 200 status
	*/
	@async function export(status:Int)
	{
		if (repo.export_options == null) {
			log("nothing to export, no 'export_options'", [ENoExport]);
			return 200;
		}
		var filtered = (repo.export_options.filter != null
				&& repo.export_options.filter.refs != null
				&& !Lambda.has(repo.export_options.filter.refs, base.branch));
		if (filtered)
			log("branch content filtered out from exporting", [ENoExport]);

		var dest = {
			buildLog : repo.export_options.destination.build_log,
			content : ((status != 200 && status != 0) || filtered) ? null : getExportPath()
		}

		if (dest.buildLog != null) {
			log("exporting the build log");
			var bpath = expandPath(dest.buildLog);
			js.npm.MkdirDashP.mkdirSync(Path.dirname(bpath));
			var err = @await copyFile(buildDir.file.robrt_build_log, bpath);
			if (err != null) {
				log('failure to export log: $err', [EExportError]);
				return 500;
			}
		}

		if (dest.content != null) {
			if (repoConf.export != null && !repoConf.export) {
				log("content export has been disabled in .robrt.json");  // notify something?
				return 200;
			}

			log("exporting", [EExporting]);
			log("exporting the build");
			dest.content = expandPath(dest.content);
			var tdir = '${dest.content}.${request.buildId}.dir';
			js.npm.MkdirDashP.mkdirSync(tdir);
			var err = @await js.npm.Ncp.ncp(buildDir.dir.to_export, tdir);
			if (err != null) {
				log('failure to export (prepare): $err', [EExportError]);
				return 500;
			}
			js.npm.Remove.removeSync(dest.content, { ignoreMissing : true });
			var err = @await js.node.Fs.rename(tdir, dest.content);
			if (err != null) {
				log('failure to export (rename): $err', [EExportError]);
				return 500;
			}
			log("export successfull", [EExportSuccess]);
			return 200;
		}

		return 500;
	}

	@async public function doCleanup()
	{
		log("starting cleanup");

		log("cleanup: remove the base build dir");
		var err = @await js.npm.Remove.remove(buildDir.dir.base, { ignoreMissing : true });
		if (err != null) log('ERROR when trying to remove the base build dir: $err');

		// TODO docker cleanup
	}

	@async public function run()
	{
		log("starting build", [EStarted]);

		buildDir = getBuildDir(repo.build_options.directory, request.buildId);
		logOutput = Fs.createWriteStream(buildDir.file.robrt_build_log);

		if (repo.build_options == null) {
			log("nothing to do, no 'build_options'", [ENoBuild]);
			return 200;
		} else if (repo.build_options.filter != null
				&& repo.build_options.filter.refs != null
				&& !Lambda.has(repo.build_options.filter.refs, base.branch)) {
			log("branch filtered out from building", [ENoBuild]);
			return 200;
		}

		docker = new Docker();

		var status = @await prepareBuild();

		if (status == 0)
			status = @await build();

		@await logOutput.end();
		status = @await export(status);

		@await doCleanup();

		if (status == 0 || status == 200) {
			log('finished with $status', [EDone]);
			return 200;
		} else {
			return status;
		}
	}

	public function new(request, repo, base)
	{
		this.request = request;
		this.repo = repo;
		this.base = base;
		tags = [
			"user" => repo.full_name.split("/")[0],  // FIXME
			"repo" => repo.full_name.split("/")[1],  // FIXME
			"base_branch" => base.branch,
			"build_id" => request.buildId
		];
		if (base.commit != null) {
			tags["base_commit"] = base.commit;
			tags["base_commit_short"] = base.commit.substr(0, 7);
		}
		notifier = new NotifierHub(tags, repo, base);
	}
}

