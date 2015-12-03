package robrt;

import js.node.*;
import js.node.stream.*;
import js.npm.dockerode.Docker;
import robrt.Variables;
import robrt.repository.RepoConfig;
import robrt.server.BuildDir;
import robrt.server.ServerConfig;

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta("async"))
class PushBuild {
	var request:IncomingRequest;
	var repo:Repository;
	var base:{ branch:String, commit:String };

	var buildDir:BuildDir;
	var repoConf:RepoConfig;
	var docker:Docker;
	var container:{ container : Container, stdouts:Readable<Dynamic>, stdin:Writable<Dynamic> };

	function log(msg:Dynamic, ?pos:haxe.PosInfos)
		request.log(msg, pos);

	static function shEscape(s:String)
	{
		return "'" + s + "'";
	}

	function getBuildDir(baseBuildDir, id):BuildDir
	{
		var base = Path.join(baseBuildDir, id);
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
	@async function openRepo(fullName:String, dest:String, base:{ branch:String, commit:String }, ?pr:{ number:Int, commit:String }, ?token:String):Bool
	{
		var url = 'https://github.com/$fullName';
		// $token would sufice, but $token:$token prevents git from asking for a password on /dev/tty
		var authUrl = if (token == null) url else StringTools.replace(url, "https://", 'https://$token:$token@');

		// clone and checkout the specified commit
		// for homegeneity with `pr != null` reset the `base.branch` to `base.commit`
		// (this ensures that we're not building some more recent version of the branch by accident)
		var commands = [
			'git clone --quiet --branch ${shEscape(base.branch)} $authUrl $dest',
			'git -C $dest checkout --quiet --force ${base.commit}',
			'git -C $dest reset --quiet --hard ${base.commit}'
		];
		if (pr != null) {
			// fetch the pull request base and branch from the specified base commit
			// (this ensures that we're not building some more recent version of the PR by accident)
			commands = commands.concat([
				'git -C $dest fetch --quiet origin pull/${pr.number}/base',
				'git -C $dest branch --quiet pull/${pr.number}/base ${pr.commit}'
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

	function buildImage(image:String, opts:Dynamic, callback:js.Error->Void)
	{
		function cb(err, out:js.node.stream.Readable<Dynamic>) {
			if (err != null) {
				callback(err);
				return;
			}
			var buf = new StringBuf();
			out.on("data", function (chunk) buf.add(chunk));
			out.on("error", callback);
			out.on("end", function () {
				var out = StringTools.trim(buf.toString()).split("\r\n");
				var last:haxe.DynamicAccess<String> = haxe.Json.parse(out[out.length - 1]);
				callback(last.exists("error") ? new js.Error(last["error"]) : null);
			});
		}
		docker.buildImage(image, opts, cb);
	}

	@async function prepareContainer(name:String, refresh:Bool)
	{
		var err = @await prepareDockerBuild(repoConf.prepare);
		if (err != null) {
			log(err);
			return null;
		}

		var imageName = 'robrt-builds:$name:${request.buildId}';
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
		var err, container = @await docker.createContainer({
			Image : imageName,
			Env : [
				'$RepoPath=$repoDir',
				'$OutPath=$expDir'
			],
			Cmd : "bash",
			Mounts : [
				{ Source : buildDir.dir.repository, Destination : repoDir },
				{ Source : buildDir.dir.to_export, Destination : expDir }
			],
			AttachStdin : true,
			AttachStdout : true,
			AttachStderr : true,
			OpenStdin : true,
			Tty : true
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
		log("cloning");
		return @await openRepo(repo.full_name, buildDir.dir.repository, base, repo.oauth2_token);
	}

	@async function prepareBuild()
	{
		buildDir = getBuildDir(repo.build_options.directory, request.buildId);

		var ok = @await prepareRepository();
		if (!ok)
			return 500;
		repoConf = readRepoConfig(buildDir.dir.repository);
		if (repoConf == null) {
			log("Invalid .robrt.json");
			return 500;
		}
		if (repoConf.prepare == null) {
			log("nothing to do; no 'prepare' in .robrt.json");
			return 200;
		}

		log("preparing");
		container = @await prepareContainer(repo.full_name, false);
		if (container == null) {
			log("FAILED: could not create container");
			return 500;
		}
		return 0;
	}

	@async function build()
	{
		if (repoConf.build == null) {
			log("nothing to do; no 'build' in .robrt.json");
			return 200;
		}

		var err, zzz = @await container.container.start();
		if (err != null) {
			log(err);
			return 500;
		}

		var buffer = "";
		for (id in 0...repoConf.build.cmds.length) {
			var cmd = repoConf.build.cmds[id];
			var wcmd = 'echo "Robrt: starting cmd <$id>"; $cmd; echo "Robrt: finished cmd <$id> with status <$$?>"\n';
			log('running $id: $cmd\nas: $wcmd');
			container.stdin.write(wcmd);
			var wait = function (chunk) {
				buffer += chunk;
				var p = new EReg('Robrt: finished cmd <$id> with status <(\\d+)>', "i");
				if (p.match(buffer)) {
					container.stdouts.emit("cmd-finished", p.matched(1));
				}
			};
			container.stdouts.on("data", wait);
			var exit = @await container.stdouts.once("cmd-finished");
			container.stdouts.removeListener("data", wait);
			if (exit != 0) {
				log('ABORTING: cmd $id exited with non-zero status $exit');
				return 500;
			}
			log('cmd $id exited with $exit');
		}
		log('output:\nbuffer');

		log("building");
		log("ABORTING: TODO build");
		return 501;
	}

	@async function export()
	{
		if (repoConf.export == null) {
			log("nothing to do; no 'export' in .robrt.json");
			return 200;
		}

		log("ABORTING: TODO export");
		return 501;
	}

	@async public function run()
	{
		log("starting build");

		if (repo.build_options == null) {
			log("nothing to do, no 'build_options'");
			return 200;
		} else if (repo.build_options.filter != null
				&& repo.build_options.filter.refs != null
				&& !Lambda.has(repo.build_options.filter.refs, base.branch)) {
			log("branch filtered out from building");
			return 200;
		}

		docker = new Docker();

		var status = @await prepareBuild();
		if (status == 0)
			status = @await build();

		// TODO close cnx to docker

		if (status != 0)
			return status;

		if (repo.export_options == null) {
			log("nothing to export, no 'export_options'");
			return 200;
		} else if (repo.export_options.filter != null
				&& repo.export_options.filter.refs != null
				&& !Lambda.has(repo.export_options.filter.refs, base.branch)) {
			log("branch filtered out from exporting");
			return 200;
		}

		status = @await export();
		return status != 0 ? status : 200;
	}

	public function new(request, repo, base)
	{
		this.request = request;
		this.repo = repo;
		this.base = base;
	}
}

