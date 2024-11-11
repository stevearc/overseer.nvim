# Changelog

## [1.5.0](https://github.com/stevearc/overseer.nvim/compare/v1.4.0...v1.5.0) (2024-11-11)


### Features

* add a plug binding for disposing a task ([b99f582](https://github.com/stevearc/overseer.nvim/commit/b99f5824acd6c5f85e94fc38f9db7315cd268b47))
* allow template params to be a function ([#86](https://github.com/stevearc/overseer.nvim/issues/86)) ([e90c397](https://github.com/stevearc/overseer.nvim/commit/e90c3976e6a1d98733dc7078a967995c039a77bd))
* API to register a component alias ([05e4f72](https://github.com/stevearc/overseer.nvim/commit/05e4f728eb2e0a42a34c73ff54b9449f0778f121))
* change default task list position to the bottom ([d070abc](https://github.com/stevearc/overseer.nvim/commit/d070abc56adc9f19e02d40ff6c1f79869310904f))
* component to show real-time notification with output summary ([#356](https://github.com/stevearc/overseer.nvim/issues/356)) ([cbcabf2](https://github.com/stevearc/overseer.nvim/commit/cbcabf231400c3a5c43ab66c4f5344d40855feba))
* highlight focused task in task list ([362f78d](https://github.com/stevearc/overseer.nvim/commit/362f78dd6a33b0de5aec7de1ead6fc866ffd1deb))
* new open_output component ([#306](https://github.com/stevearc/overseer.nvim/issues/306)) ([76561a4](https://github.com/stevearc/overseer.nvim/commit/76561a435aaad1dc105a0e6ae06cc122a0d97cdb))
* on_complete_dispose can wait until task buffer has been seen ([9162631](https://github.com/stevearc/overseer.nvim/commit/916263159f5e1ab85f1ee10456fe651f8665c4f5))
* on_result_diagnostics_trouble component to integrate with trouble.nvim ([cc33e6e](https://github.com/stevearc/overseer.nvim/commit/cc33e6e9919394dba1a5841a9ea93f2b0a6e14d7))
* **vscode:** support presentation.reveal and presentation.revealProblems ([2d52e80](https://github.com/stevearc/overseer.nvim/commit/2d52e8069349dcb4233ff9024cd358954367df61))


### Bug Fixes

* add debug logging to on_complete_dispose ([d78fa84](https://github.com/stevearc/overseer.nvim/commit/d78fa84c06d37b1eb3bd42b4b5467c7476e74589))
* allow setting toggleterm size in strategy ([#328](https://github.com/stevearc/overseer.nvim/issues/328)) ([d82f207](https://github.com/stevearc/overseer.nvim/commit/d82f20734953be76f28431584b8d3058399a6bb7))
* always parse make output to find tasks ([#280](https://github.com/stevearc/overseer.nvim/issues/280)) ([f7507de](https://github.com/stevearc/overseer.nvim/commit/f7507de00d4b25aa7242353ccd22a4a5f052a2a8))
* cmp completion supports more characters ([#340](https://github.com/stevearc/overseer.nvim/issues/340)) ([09d07e3](https://github.com/stevearc/overseer.nvim/commit/09d07e398b71eec2810e2ff265a843e474297e44))
* crash when aborting task watch form ([03cbbb7](https://github.com/stevearc/overseer.nvim/commit/03cbbb7d5628c55f0038f846cdffdc3a95e16a90))
* **dap:** stop debugging if preLaunchTask fails ([#344](https://github.com/stevearc/overseer.nvim/issues/344)) ([236e60c](https://github.com/stevearc/overseer.nvim/commit/236e60cdac6410dd95ea5cecafdb801a304d6a41))
* define clear rules for when task list focus should change ([a6dc060](https://github.com/stevearc/overseer.nvim/commit/a6dc0600f675f10b8840c61d3f9d72fdf8cf970c))
* delete task bundle on save if no tasks and on_conflict=overwrite ([#374](https://github.com/stevearc/overseer.nvim/issues/374)) ([c416be5](https://github.com/stevearc/overseer.nvim/commit/c416be50c2715a7f631d67e21154b8e6cd873ca3))
* disable template caching unless provider specifically enables it ([6511b0e](https://github.com/stevearc/overseer.nvim/commit/6511b0ee9a54e6b18587aa3c9c55c97fa8bf6bdd))
* don't warn on user defined vscode variables ([#325](https://github.com/stevearc/overseer.nvim/issues/325)) ([98ce1c8](https://github.com/stevearc/overseer.nvim/commit/98ce1c85c6b9fe16b140c5f9c1d25298b3605c6f))
* focus race condition when adding new components ([#311](https://github.com/stevearc/overseer.nvim/issues/311)) ([09b1839](https://github.com/stevearc/overseer.nvim/commit/09b18396b974e67cf626a24afa74803c6650a4d5))
* **form:** handle enum values with special characters ([#341](https://github.com/stevearc/overseer.nvim/issues/341)) ([6fdb72e](https://github.com/stevearc/overseer.nvim/commit/6fdb72eca78015f00cf9e43e0578f1bfdb984acc))
* fzf-lua crash when running OverseerTaskAction ([8438119](https://github.com/stevearc/overseer.nvim/commit/8438119c3207274cc5f6823ea9b476a3d9cae849))
* **go-task:** fix template to set working dir for task ([#295](https://github.com/stevearc/overseer.nvim/issues/295)) ([5fc6848](https://github.com/stevearc/overseer.nvim/commit/5fc6848307b9a00088f80f6e25041954da8416d2))
* handle consumer access before neotest is initialized ([#352](https://github.com/stevearc/overseer.nvim/issues/352)) ([a2734d9](https://github.com/stevearc/overseer.nvim/commit/a2734d90c514eea27c4759c9f502adbcdfbce485))
* miscalculation in task focus logic ([9e3b11a](https://github.com/stevearc/overseer.nvim/commit/9e3b11adf5ca1bb2753c76623f2c07b8c5c0d18e))
* number column randomly appears when opening output ([#371](https://github.com/stevearc/overseer.nvim/issues/371)) ([6f8bc37](https://github.com/stevearc/overseer.nvim/commit/6f8bc37eb729a00e185cdf38b1ed3309a05bfeef))
* orchestrator can take template definitions or task definitions ([#273](https://github.com/stevearc/overseer.nvim/issues/273)) ([a12d886](https://github.com/stevearc/overseer.nvim/commit/a12d8865a71ce0c5861a36a731264c915be35d7f))
* orchestrator strategy allows empty task lists ([#309](https://github.com/stevearc/overseer.nvim/issues/309)) ([29dd31d](https://github.com/stevearc/overseer.nvim/commit/29dd31db39b44ddd57cfbc70610181a23acfae47))
* orchestrator tasks sometimes not recognized ([#379](https://github.com/stevearc/overseer.nvim/issues/379)) ([25a9c64](https://github.com/stevearc/overseer.nvim/commit/25a9c6439a37b680ff4b3c02554f4173c197c18b))
* pass cwd for cargo-make and deno tasks ([#337](https://github.com/stevearc/overseer.nvim/issues/337)) ([8e4ca87](https://github.com/stevearc/overseer.nvim/commit/8e4ca87f6073507b891a22ba9261bec309b05e9a))
* preview scroll shortcuts ([#312](https://github.com/stevearc/overseer.nvim/issues/312)) ([9420d58](https://github.com/stevearc/overseer.nvim/commit/9420d5814e22ea2c6380a0aa213059098c708778))
* proper escaping for single quotes ([#308](https://github.com/stevearc/overseer.nvim/issues/308)) ([fbf5330](https://github.com/stevearc/overseer.nvim/commit/fbf53309616b8c9489c66e9cdfe9761d0046ab82))
* properly catch errors in run_in_fullscreen_win ([#377](https://github.com/stevearc/overseer.nvim/issues/377)) ([9f2145e](https://github.com/stevearc/overseer.nvim/commit/9f2145efd7b88ae6b811a301d2bd20e0784885ac))
* provide full stacktrace when provider errors ([80156d8](https://github.com/stevearc/overseer.nvim/commit/80156d861c4a61b521e85e6220091adee910c445))
* return on_result_diagnostics to default_vscode group ([e5723f2](https://github.com/stevearc/overseer.nvim/commit/e5723f2e84042a83354612b6daf7511441c7c9c0))
* scrolling shortcuts work for all output windows ([#312](https://github.com/stevearc/overseer.nvim/issues/312)) ([6271cab](https://github.com/stevearc/overseer.nvim/commit/6271cab7ccc4ca840faa93f54440ffae3a3918bd))
* small fixes to VSCode variable interpolation ([87526ba](https://github.com/stevearc/overseer.nvim/commit/87526babdb563b9e2f0646b420359389732326dc))
* strip newlines before rendering ([#364](https://github.com/stevearc/overseer.nvim/issues/364)) ([965f815](https://github.com/stevearc/overseer.nvim/commit/965f8159408cee5970421ad36c4523333b798502))
* support bun.lock ([#361](https://github.com/stevearc/overseer.nvim/issues/361)) ([e933735](https://github.com/stevearc/overseer.nvim/commit/e93373531dec5b1cc6d7ae6b7c786da44936a5b3))
* **toggleterm:** better integration with the 'open' actions ([#159](https://github.com/stevearc/overseer.nvim/issues/159)) ([6a4008d](https://github.com/stevearc/overseer.nvim/commit/6a4008deab806a4a4157e34b4874141596b3b985))
* **toggleterm:** exit for fish shell ([#345](https://github.com/stevearc/overseer.nvim/issues/345)) ([2c1ef39](https://github.com/stevearc/overseer.nvim/commit/2c1ef39d105eb0d707020d32f68843379044d0a6))
* **toggleterm:** various issues with toggleterm strategy ([1f5f271](https://github.com/stevearc/overseer.nvim/commit/1f5f271e00b82ced6a30ae5ad6dbe7d1104e5980))
* use listener hooks for nvim-dap instead of monkey patching ([ecdfbac](https://github.com/stevearc/overseer.nvim/commit/ecdfbac807652a374414d3d6f3e5b3af201f884d))
* use the default toggleterm direction by default ([#332](https://github.com/stevearc/overseer.nvim/issues/332)) ([cbcdcba](https://github.com/stevearc/overseer.nvim/commit/cbcdcbae3704c21d3ff96a1927d952b8a966b08a))
* vscode task hide option was not set correctly ([#329](https://github.com/stevearc/overseer.nvim/issues/329)) ([2a540de](https://github.com/stevearc/overseer.nvim/commit/2a540de6d97581399b3cc6ea9126cf5737cdcdbe))
* warn when nvim-dap is too old to be supported ([#307](https://github.com/stevearc/overseer.nvim/issues/307)) ([d13ef57](https://github.com/stevearc/overseer.nvim/commit/d13ef578359ebf94d5c28757c252489ba94821a8))

## [1.4.0](https://github.com/stevearc/overseer.nvim/compare/v1.3.1...v1.4.0) (2024-05-16)


### Features

* add a new "run" tag to tasks ([#263](https://github.com/stevearc/overseer.nvim/issues/263)) ([792aeb6](https://github.com/stevearc/overseer.nvim/commit/792aeb6d834a11585ea5d667e3e3f05bc6aa4ecc))
* add config option to disable autostart when loading tasks ([#245](https://github.com/stevearc/overseer.nvim/issues/245)) ([de07357](https://github.com/stevearc/overseer.nvim/commit/de0735710f386acccf4489b86f95d7956d1973ec))
* add mage template provider ([#253](https://github.com/stevearc/overseer.nvim/issues/253)) ([68a2d34](https://github.com/stevearc/overseer.nvim/commit/68a2d344cea4a2e11acfb5690dc8ecd1a1ec0ce0))
* support for vscode's "hide" option ([#272](https://github.com/stevearc/overseer.nvim/issues/272)) ([b04b0b1](https://github.com/stevearc/overseer.nvim/commit/b04b0b105c07b4f02b3073ea3a98d6eca90bf152))


### Bug Fixes

* add missing space after `running` glyph ([#282](https://github.com/stevearc/overseer.nvim/issues/282)) ([dd701ed](https://github.com/stevearc/overseer.nvim/commit/dd701ed0639ef1e10d0ca8dec039719e916c4a7b))
* eslint and jshint problem matcher patterns ([#260](https://github.com/stevearc/overseer.nvim/issues/260)) ([4855aef](https://github.com/stevearc/overseer.nvim/commit/4855aefcf335bbac71eea9c6a888958fb1ed1e1a))
* if fetching task by tags, ignore tasks with no tags ([#252](https://github.com/stevearc/overseer.nvim/issues/252)) ([d3f9a02](https://github.com/stevearc/overseer.nvim/commit/d3f9a0205640bda1fb68b5011b427ec4e70f9616))
* **npm:** smarter package.json file detection ([#250](https://github.com/stevearc/overseer.nvim/issues/250)) ([facb48f](https://github.com/stevearc/overseer.nvim/commit/facb48fbd768c47d75d8be9f44ec948bbe4a6064))
* problem matcher uses message from non-loop pattern ([#247](https://github.com/stevearc/overseer.nvim/issues/247)) ([93cf38a](https://github.com/stevearc/overseer.nvim/commit/93cf38a3e9914a18a7cf6032c6a19f87a22db3c9))
* refactor deprecated methods in neovim 0.10 ([c1bbc26](https://github.com/stevearc/overseer.nvim/commit/c1bbc2646b3bc1a0066cff033d3f9d1b754c2cf1))
* remove calls to deprecated tbl_add_reverse_lookup ([b72f6d2](https://github.com/stevearc/overseer.nvim/commit/b72f6d23ce47ccd427be2341f389c63448278f17))
* run_in_cwd runs in current buffer by default ([e532dbb](https://github.com/stevearc/overseer.nvim/commit/e532dbbe0b3fe27eb485d3868c2afb552449f232))
* set default winblend to 0 ([#292](https://github.com/stevearc/overseer.nvim/issues/292)) ([7dc625d](https://github.com/stevearc/overseer.nvim/commit/7dc625ded6aee673e4ac6b573d1fdb985c7bb38c))
* update type definitions for overseer.setup() ([7ae60fc](https://github.com/stevearc/overseer.nvim/commit/7ae60fcf9b1d9ad661e8936d50c6e3853b7c3cc0))
* update type definitions for overseer.setup() ([#289](https://github.com/stevearc/overseer.nvim/issues/289)) ([cd46ead](https://github.com/stevearc/overseer.nvim/commit/cd46ead99cc4187bb4e466a328cb3ecc3d84f38d))

## [1.3.1](https://github.com/stevearc/overseer.nvim/compare/v1.3.0...v1.3.1) (2023-12-23)


### Bug Fixes

* can close overseer sidebar if it's the last window open ([#218](https://github.com/stevearc/overseer.nvim/issues/218)) ([ffd7be7](https://github.com/stevearc/overseer.nvim/commit/ffd7be72399715112e1a4908d6587fa7ea805a26))
* cargo-make task search pattern ([#227](https://github.com/stevearc/overseer.nvim/issues/227)) ([95bd2d4](https://github.com/stevearc/overseer.nvim/commit/95bd2d45af543238e25919ad2d9793a8cf61ac38))
* disallow empty bundle name ([#223](https://github.com/stevearc/overseer.nvim/issues/223)) ([400e762](https://github.com/stevearc/overseer.nvim/commit/400e762648b70397d0d315e5acaf0ff3597f2d8b))
* don't open new buffer when closing overseer task list ([5e84981](https://github.com/stevearc/overseer.nvim/commit/5e8498131867cd1b7c676ecdd1382ab2fd347dde))
* incorrect handling of vim.fn.executable return value ([6f462a6](https://github.com/stevearc/overseer.nvim/commit/6f462a61ce9a5f47743cbf78454bed14a855eb03))
* **mix:** invoke in the folder of the mix.exs ([#241](https://github.com/stevearc/overseer.nvim/issues/241)) ([27795de](https://github.com/stevearc/overseer.nvim/commit/27795de05f6f72fd1bc19b6cbba287e2516f37f9))
* on_result_diagnostics_quickfix preserves window focus ([#237](https://github.com/stevearc/overseer.nvim/issues/237)) ([6e3ab7e](https://github.com/stevearc/overseer.nvim/commit/6e3ab7e803dbda13fa6270f1b37ad68bad8141e5))
* remove type restriction when searching for justfile ([#222](https://github.com/stevearc/overseer.nvim/issues/222)) ([0be4966](https://github.com/stevearc/overseer.nvim/commit/0be4966c0bd2010eaabd5b4b8e34902807b756fb))
* set cwd to package dir in npm template ([#228](https://github.com/stevearc/overseer.nvim/issues/228)) ([1e64be8](https://github.com/stevearc/overseer.nvim/commit/1e64be857562607041d02ee775f593f3a01f9137))
* support 'note' and 'info' quickfix types in on_result_diagnostics ([#220](https://github.com/stevearc/overseer.nvim/issues/220)) ([4b811f8](https://github.com/stevearc/overseer.nvim/commit/4b811f8283dde37b38cb369a6397933c30eacaf3))

## [1.3.0](https://github.com/stevearc/overseer.nvim/compare/v1.2.0...v1.3.0) (2023-10-06)


### Features

* add close task list keybinding ([#215](https://github.com/stevearc/overseer.nvim/issues/215)) ([0c72f52](https://github.com/stevearc/overseer.nvim/commit/0c72f52eaed32a8317fad6de2a5a30018d4a8f83))
* basic bun support ([#196](https://github.com/stevearc/overseer.nvim/issues/196)) ([1bd4ae6](https://github.com/stevearc/overseer.nvim/commit/1bd4ae6fb6945fefa98b9ce9b2c34fc1d09da252))
* namedEnum parameter type ([#217](https://github.com/stevearc/overseer.nvim/issues/217)) ([c14d9f3](https://github.com/stevearc/overseer.nvim/commit/c14d9f330f8c397d5cff528992607af278dd814e))
* new action to open task buffer in new tab ([ff6e5c5](https://github.com/stevearc/overseer.nvim/commit/ff6e5c5342b2ec70e105e1c3fc9841884f02f560))
* visually group subtasks in sidebar ([6fe36fc](https://github.com/stevearc/overseer.nvim/commit/6fe36fc338fbeaf35b0f801c25f7f231c431a64b))


### Bug Fixes

* concatenate nil ([#209](https://github.com/stevearc/overseer.nvim/issues/209)) ([8065976](https://github.com/stevearc/overseer.nvim/commit/8065976876cea89d0b99ffef4d997b930296f0e8))
* ignore case when searching for "justfile", support hidden files ([#198](https://github.com/stevearc/overseer.nvim/issues/198)) ([2749d88](https://github.com/stevearc/overseer.nvim/commit/2749d8893a069a0020eba3ddbc26f1624a57d7b3))
* is_absolute function on windows ([ae0c54c](https://github.com/stevearc/overseer.nvim/commit/ae0c54c325d2018775049bdd1cd76403015d0b90))
* lazy-load dap when patching ([#213](https://github.com/stevearc/overseer.nvim/issues/213)) ([b24a027](https://github.com/stevearc/overseer.nvim/commit/b24a027af87160bfe78a599942a57ab21ffcbdf9))
* npm task type for VS Code tasks ([#211](https://github.com/stevearc/overseer.nvim/issues/211)) ([dbc7bcf](https://github.com/stevearc/overseer.nvim/commit/dbc7bcf8c064ec892d99af6ac462fcaeda59da4a))
* on_output_write_file creates parent dir if necessary ([b24e90d](https://github.com/stevearc/overseer.nvim/commit/b24e90dabd15ad26f067ea84d6a02e16245cd9c8))
* parent tasks sort to top above dependencies ([#199](https://github.com/stevearc/overseer.nvim/issues/199)) ([4e654e1](https://github.com/stevearc/overseer.nvim/commit/4e654e18e5eae34c7f1d684f5a97e3a77e796a2b))
* save and restore sidebar window view ([#216](https://github.com/stevearc/overseer.nvim/issues/216)) ([3258e2a](https://github.com/stevearc/overseer.nvim/commit/3258e2a83bb09daee660bf849e9a0d85356992e7))
* VSCode problem matcher conversion to parser ([#211](https://github.com/stevearc/overseer.nvim/issues/211)) ([83a22c0](https://github.com/stevearc/overseer.nvim/commit/83a22c02caf79e5f671d1614001ed1c4dc63ddab))

## [1.2.0](https://github.com/stevearc/overseer.nvim/compare/v1.1.0...v1.2.0) (2023-09-13)


### Features

* allow configuration of help float ([#194](https://github.com/stevearc/overseer.nvim/issues/194)) ([3555359](https://github.com/stevearc/overseer.nvim/commit/3555359e1778068eca01e78ac56b91f66257f551))


### Bug Fixes

* expose the patch_dap method ([c1ef281](https://github.com/stevearc/overseer.nvim/commit/c1ef281a078d2f815ec669f4b1af358d5624ccda))
* guard teardown in task bundle selector ([#192](https://github.com/stevearc/overseer.nvim/issues/192)) ([c6ec203](https://github.com/stevearc/overseer.nvim/commit/c6ec203ddbdfe352e54cbc577f5db911dbb7db55))
* resession extension only saves data if any tasks present ([8a83090](https://github.com/stevearc/overseer.nvim/commit/8a830905c10d929033aa0fefa318fb6d9e18f5b8))
* search for VS Code tasks in cwd first ([#188](https://github.com/stevearc/overseer.nvim/issues/188)) ([b1cd700](https://github.com/stevearc/overseer.nvim/commit/b1cd7007b78d636b93f13eac27069bb007147f04))

## [1.1.0](https://github.com/stevearc/overseer.nvim/compare/v1.0.0...v1.1.0) (2023-09-01)


### Features

* add additional commands to cargo ([#172](https://github.com/stevearc/overseer.nvim/issues/172)) ([514a5e1](https://github.com/stevearc/overseer.nvim/commit/514a5e1af18b490721836fa19b62ca60761e5b59))
* add buffer-local variable linking buffers to task ID ([#169](https://github.com/stevearc/overseer.nvim/issues/169)) ([4d046a1](https://github.com/stevearc/overseer.nvim/commit/4d046a116c80db4300a66a58288a6b75b5a8c54f))


### Bug Fixes

* chunk lost when parsing output from stdout ([#185](https://github.com/stevearc/overseer.nvim/issues/185)) ([d4118da](https://github.com/stevearc/overseer.nvim/commit/d4118da29d8cdba81661854ac4be14175e2f8de5))
* gcc problem matcher regular expression on windows ([#178](https://github.com/stevearc/overseer.nvim/issues/178)) ([4f8ea34](https://github.com/stevearc/overseer.nvim/commit/4f8ea3487cbbea8f6b477a6af13c6c6e2f7ff6fd))
* invalid highlight group for neovim 0.8 ([b44fd57](https://github.com/stevearc/overseer.nvim/commit/b44fd57d1ba47a48e843393bdc0198cacb2a6859))
* orchestrator strategy can set cwd for individual tasks ([#174](https://github.com/stevearc/overseer.nvim/issues/174)) ([16ac26a](https://github.com/stevearc/overseer.nvim/commit/16ac26aebef2468fda76de2b913bb6b76193932f))
* orchestrator tasks clobber cwd set by builder function ([#180](https://github.com/stevearc/overseer.nvim/issues/180)) ([cdee07c](https://github.com/stevearc/overseer.nvim/commit/cdee07c73d257e7aaa8d2bb4cac238c4c1b103c9))
* precalculate VS Code task variables ([#181](https://github.com/stevearc/overseer.nvim/issues/181)) ([020f63d](https://github.com/stevearc/overseer.nvim/commit/020f63d4cb97f54b61caa533ad9d176c543ef0ab))
* shell task accepts components and strategy params ([#182](https://github.com/stevearc/overseer.nvim/issues/182)) ([18c06d3](https://github.com/stevearc/overseer.nvim/commit/18c06d3d9bd9ea376240e34ae60f3da76f1aa5f9))
* type errors and annotations ([667dc5f](https://github.com/stevearc/overseer.nvim/commit/667dc5f0048d299fc41c13c8c3b5ef2cb2909a4d))

## 1.0.0 (2023-06-27)


### ⚠ BREAKING CHANGES

* don't auto-add on_result_diagnostics to VS Code tasks ([#163](https://github.com/stevearc/overseer.nvim/issues/163))
* search for tasks relative to open file
* announce new requirement for Neovim 0.8+
* restart_on_save component param "path" -> "paths"
* Support for VS Code Azure func tasks

### Features

* accepte 'None' binding to avoid default bindings ([3c69de0](https://github.com/stevearc/overseer.nvim/commit/3c69de008bf6ceaa140ca0854a17e74aec346150))
* add  problemMatcher from vscode-cpptools ([d1858b0](https://github.com/stevearc/overseer.nvim/commit/d1858b06416dc56fd3b94d9a1f2af74a953d42fc))
* add 'order' to params to allow defining UI order ([0aeba9b](https://github.com/stevearc/overseer.nvim/commit/0aeba9b873d1ba072e41458f0b35c2e405b072e9))
* add a 'shell' template for running raw commands ([05835f6](https://github.com/stevearc/overseer.nvim/commit/05835f64fd438ba3a9e22bf8adf01202ca0e2d24))
* add a composer template ([574d7ed](https://github.com/stevearc/overseer.nvim/commit/574d7eded26fddf136624c33f01b6b93ec433eb1))
* add action to open task buffer in horizontal split ([57b1d3d](https://github.com/stevearc/overseer.nvim/commit/57b1d3dcd5d3c27e86a48e1ba7efdb0e37dad380))
* add an "unwatch" action ([#51](https://github.com/stevearc/overseer.nvim/issues/51)) ([2717605](https://github.com/stevearc/overseer.nvim/commit/271760514c2570dc544c45d3ca9754dcf2785a41))
* add better resession support ([2fbfcd1](https://github.com/stevearc/overseer.nvim/commit/2fbfcd131dd4c1f461d839925a335e80b9775b81))
* add default_template_prompt config option ([#18](https://github.com/stevearc/overseer.nvim/issues/18)) ([f8b3ffa](https://github.com/stevearc/overseer.nvim/commit/f8b3ffaadc06158d908abcea1fc9c7b775d7963c))
* add diagnostic report to template list command for :OverseerInfo ([0b16a1e](https://github.com/stevearc/overseer.nvim/commit/0b16a1ea05b1bd961bcbfd16bad9b17fbc905c8c))
* add new prompt value 'avoid' and rework 'allow' ([#57](https://github.com/stevearc/overseer.nvim/issues/57)) ([1f3cd54](https://github.com/stevearc/overseer.nvim/commit/1f3cd54f2890b02af9ebacec39ac62d766993d44))
* add on_preprocess_result event ([#117](https://github.com/stevearc/overseer.nvim/issues/117)) ([b5f1632](https://github.com/stevearc/overseer.nvim/commit/b5f1632ecb7f730b4726f2b3126971aad0928643))
* add open_on_exit param for on_output_quickfix component ([7e094f6](https://github.com/stevearc/overseer.nvim/commit/7e094f65817281ee96ee671b96a11e043b9173de))
* add OpenSplit to task list bindings ([bc3e0a6](https://github.com/stevearc/overseer.nvim/commit/bc3e0a6105a48e78a1dd286fbe1c855882f62319))
* add options to run task save/load non-interactively ([1754c35](https://github.com/stevearc/overseer.nvim/commit/1754c35f511ba5d59657e02529403cd42d966e81))
* add overseer.hook_template ([d410e8f](https://github.com/stevearc/overseer.nvim/commit/d410e8fc129d3fbf6ee515669f5f3dad1db7112c))
* add OverseerClearCache command ([ca1cf5e](https://github.com/stevearc/overseer.nvim/commit/ca1cf5e6b6792fdef418b7e80ded9e978cfb84f1))
* add quit_on_exit option for toggleterm strategy ([60e4e10](https://github.com/stevearc/overseer.nvim/commit/60e4e104c88b98ad69e7fff850eb1811542cabab))
* add resession.nvim extension ([6fd97ed](https://github.com/stevearc/overseer.nvim/commit/6fd97ed194d6bb35a954b541a3ec8f13107577ac))
* add support for cargo clippy ([3f13587](https://github.com/stevearc/overseer.nvim/commit/3f13587244f9b37bc0e158f6f25e84ddf2b671ec))
* Add support for cargo-make ([c26b02d](https://github.com/stevearc/overseer.nvim/commit/c26b02dde9b27af994ccc56816e7d8f11edb5171))
* add support for just tasks ([#22](https://github.com/stevearc/overseer.nvim/issues/22)) ([6849468](https://github.com/stevearc/overseer.nvim/commit/684946843daf3cf005875cad9a3a3f613308c153))
* add template_timeout config option ([#43](https://github.com/stevearc/overseer.nvim/issues/43)) ([725b57e](https://github.com/stevearc/overseer.nvim/commit/725b57e77ece8dad68e5a9870ef7660a646267b9))
* add unique component ([#32](https://github.com/stevearc/overseer.nvim/issues/32)) ([a9b64d4](https://github.com/stevearc/overseer.nvim/commit/a9b64d4e2d82c8710c8fb6d29ea63c54a4151653))
* allow easy access to VS Code-style problem matchers ([56e53a4](https://github.com/stevearc/overseer.nvim/commit/56e53a4ee421d9b4d4bcb6fb3c9f67da0dbcb41f))
* allow neotest strategy components to be a function ([92e8a0d](https://github.com/stevearc/overseer.nvim/commit/92e8a0dc612bc546932a0ca0ea5302ae2f1e2f78))
* allow template generators to be async ([ce49d52](https://github.com/stevearc/overseer.nvim/commit/ce49d5237546e441a1780331d5d8ec1cd9bf9155))
* automatic caching of template providers ([49c22ec](https://github.com/stevearc/overseer.nvim/commit/49c22ec1aa7183203c98326ed531292070d2d448))
* automatically clear template cache when files are written ([3814cd4](https://github.com/stevearc/overseer.nvim/commit/3814cd49553cc3bf9c83bc891c9fb8bc023ce672))
* bindings to scroll preview or output windows ([#140](https://github.com/stevearc/overseer.nvim/issues/140)) ([2227cbe](https://github.com/stevearc/overseer.nvim/commit/2227cbeb0b1a46a4fc3bbf12d897ad4863c9c2df))
* Can add and remove template hooks ([a13cc55](https://github.com/stevearc/overseer.nvim/commit/a13cc55f951b4e7995eb695207a86a896d3798ba))
* **cargo:** add run subcommand ([96a055d](https://github.com/stevearc/overseer.nvim/commit/96a055df36ff361bf8f22bad1e6c8dc1a82ab6ba))
* **cargo:** change conditional callback function ([b765b90](https://github.com/stevearc/overseer.nvim/commit/b765b90944bf412977ad8fd873b531205df7e6ee))
* catch and log errors in lazy setup functions ([3427960](https://github.com/stevearc/overseer.nvim/commit/3427960953ae27448a1022aed2f9fef3e1de43ac))
* component that notifies on task result ([be3b36b](https://github.com/stevearc/overseer.nvim/commit/be3b36bb884a6545daeb738d781f3e63059bbec8))
* conditions for template hooks ([#38](https://github.com/stevearc/overseer.nvim/issues/38)) ([325c9e4](https://github.com/stevearc/overseer.nvim/commit/325c9e4844e8a4515280c899ab69ca0511e216d2))
* config option to set which tasks get saved to a bundle ([c4249c5](https://github.com/stevearc/overseer.nvim/commit/c4249c5cb3a8d5db4e42696d6c552d14fbc3873b))
* **config:** add OpenQuickFix binding as &lt;C-q&gt; ([b2b3448](https://github.com/stevearc/overseer.nvim/commit/b2b344899550b8f245ce28462019c0a124fabffb))
* confirm dialog places options on one line when possible ([e99df08](https://github.com/stevearc/overseer.nvim/commit/e99df0831ca27bf05402fe59501191f8ca58e8ab))
* dependencies component can define deps as a raw task definition ([adb93c4](https://github.com/stevearc/overseer.nvim/commit/adb93c492b013bfce2331c6224428576955ee96f))
* dependencies component supports template params ([0fe07f4](https://github.com/stevearc/overseer.nvim/commit/0fe07f4df8968ec3a926a0d913a59e388b22f624))
* expand cmd in shell template ([#49](https://github.com/stevearc/overseer.nvim/issues/49)) ([dee3dc6](https://github.com/stevearc/overseer.nvim/commit/dee3dc65f2885c55ebfcf695cb4a67d344f228d3))
* expose form bindings in config ([7bcdef9](https://github.com/stevearc/overseer.nvim/commit/7bcdef9493ec03ac68138979e104748d2e3909fd))
* Expose list_tasks in top-level API ([de7cb6b](https://github.com/stevearc/overseer.nvim/commit/de7cb6bb1bd802367d674e6ec653b094ee07972a))
* Expose load_template in the API ([d51658b](https://github.com/stevearc/overseer.nvim/commit/d51658bec620cc1adc0ee1483f5ee9b6fe4ff5db))
* fallback to parsing make output if treesitter parser missing ([e997030](https://github.com/stevearc/overseer.nvim/commit/e997030e581d2b3918dc642895eb4aa2e1b429c4))
* helper for creating watch task output parsers ([8ef2b30](https://github.com/stevearc/overseer.nvim/commit/8ef2b30b00a3effcd58159b87467e4e82bd08d6c))
* jobstart strategy can use raw buffer as renderer ([#65](https://github.com/stevearc/overseer.nvim/issues/65)) ([d67b8de](https://github.com/stevearc/overseer.nvim/commit/d67b8de26643b01a52946ba22ca34c5c02e370e6))
* keymaps to close and exit forms ([d8a4cbe](https://github.com/stevearc/overseer.nvim/commit/d8a4cbe6e761fb6b02b9996c4fe114fd033620a5))
* mechanism for tasks to supply default params to components ([#33](https://github.com/stevearc/overseer.nvim/issues/33)) ([a40811d](https://github.com/stevearc/overseer.nvim/commit/a40811d8591f06d35e33cada247c1bb6c4b336aa))
* neotest integration streaming support ([91a5636](https://github.com/stevearc/overseer.nvim/commit/91a5636d1748a9ef219a2c6047a751a743d13015))
* neotest tasks attempt to include the position in the name ([c6767d2](https://github.com/stevearc/overseer.nvim/commit/c6767d29dac30cb1ab2299039f07b3720445e2fc))
* new action "retain" to prevent task from being disposed after complete ([05b6651](https://github.com/stevearc/overseer.nvim/commit/05b6651c34e8e33d8d694880b41dce766aa24efb))
* new capabilities and refactoring for on_output_quickfix ([9cef54a](https://github.com/stevearc/overseer.nvim/commit/9cef54aa813eda2ae7f2b59142733e56fec4e2b5))
* new component to display task run duration ([df7b6e5](https://github.com/stevearc/overseer.nvim/commit/df7b6e5925fc56aa043576f9b57be99af1aaa194))
* new run_after component to run tasks after a task completes ([5b9c81a](https://github.com/stevearc/overseer.nvim/commit/5b9c81a2db34f73c98c7bfe072c3ebbf1eb4bac8))
* new strategy that uses jobstart instead of termopen ([45351f5](https://github.com/stevearc/overseer.nvim/commit/45351f50745ca4c83910aaad4de7d66e0acdb4ac))
* npm template provider loads workspace tasks ([d0005bb](https://github.com/stevearc/overseer.nvim/commit/d0005bb825567714aa4f642aedd9b79d21a65fd3))
* **npm:** detect pnpm ([612f8b0](https://github.com/stevearc/overseer.nvim/commit/612f8b0b7196db37169f2ff84e1ea07cb83377f1))
* on_output_parse can handle watch task output ([28b92c0](https://github.com/stevearc/overseer.nvim/commit/28b92c08bc75d100e9990040ecce3886782ce014))
* option to not autostart tasks when loading bundle ([#95](https://github.com/stevearc/overseer.nvim/issues/95)) ([35d7d73](https://github.com/stevearc/overseer.nvim/commit/35d7d739b4c95c3710ef6c113d94af0af92b7b54))
* parser node to dispatch events ([52409c1](https://github.com/stevearc/overseer.nvim/commit/52409c132ab7a55a5b13669ef2a801dca50dd458))
* parser node to extract with errorformat ([cced9be](https://github.com/stevearc/overseer.nvim/commit/cced9beb0e312747f6b41c30e67115371c7abc30))
* pre-task-creation hook ([dc3926d](https://github.com/stevearc/overseer.nvim/commit/dc3926d46bca2d47f86c3d936dd024c6b146ba75))
* problem_matcher supports vim_regexp and lua_pat ([ab46cf2](https://github.com/stevearc/overseer.nvim/commit/ab46cf241a95b106f41f19a59c16a7d1a275cc3a))
* replace "None" by false for removing default binding ([4fc1f24](https://github.com/stevearc/overseer.nvim/commit/4fc1f243fd5b178e906c380b01047b9ad6a2e328))
* restart_on_save can use libuv file watchers ([b917f6a](https://github.com/stevearc/overseer.nvim/commit/b917f6a50865b592f464be0bb26add4e03b6bdaf))
* run_template accepts cwd and env ([6d1d4c3](https://github.com/stevearc/overseer.nvim/commit/6d1d4c3a0cd6ae3405d73bebfbdba5f97289930c))
* setting a binding removes the default key for that binding ([#3](https://github.com/stevearc/overseer.nvim/issues/3)) ([a308df1](https://github.com/stevearc/overseer.nvim/commit/a308df1f4f62afed36227b04f7bb363d2354db20))
* show neotest position in task name ([1e04e69](https://github.com/stevearc/overseer.nvim/commit/1e04e695ac335f5b57ea8a14235b527a13930adf))
* sidebar can open on the bottom of the editor ([#134](https://github.com/stevearc/overseer.nvim/issues/134)) ([0ce9331](https://github.com/stevearc/overseer.nvim/commit/0ce9331160c8c9954f9bddf07fc7e747cec6e30f))
* squash history for alpha release ([43b8ce0](https://github.com/stevearc/overseer.nvim/commit/43b8ce032637f8aae7c59cf11e06a729ca6eb926))
* string parameters can conceal values ([#87](https://github.com/stevearc/overseer.nvim/issues/87)) ([5d4aa57](https://github.com/stevearc/overseer.nvim/commit/5d4aa5786af479a0408b55a06d3aff260c8b2a91))
* support for deno's task runner ([e30c705](https://github.com/stevearc/overseer.nvim/commit/e30c70529c3e536fe7a837c8748278bbff616d4b))
* support for restarting neotest tasks ([3e8763e](https://github.com/stevearc/overseer.nvim/commit/3e8763e997f295e908f2704fe025da97df645ba4))
* support for taskfile ([db9a9c4](https://github.com/stevearc/overseer.nvim/commit/db9a9c482174849eb44a5c05661c21bd42ffbdb2))
* Support for VS Code Azure func tasks ([0e79574](https://github.com/stevearc/overseer.nvim/commit/0e79574de42ddd0884d949973249fa2ed6a29281))
* support make tasks in subdirectories of makefile ([a5f2e68](https://github.com/stevearc/overseer.nvim/commit/a5f2e6894e9b1a0612dc1c63372304e8e96a9a15))
* support VS Code shell quoting ([#119](https://github.com/stevearc/overseer.nvim/issues/119)) ([4c883d4](https://github.com/stevearc/overseer.nvim/commit/4c883d45a490916ed17de1f3bad7782c1a2894c2))
* task builder and editor support :w to submit ([6843b53](https://github.com/stevearc/overseer.nvim/commit/6843b53175f1c11ca566ab6ff5cffc2e09a6bf34))
* **task_list:** add open in quickfix binding ([687b09a](https://github.com/stevearc/overseer.nvim/commit/687b09a1175c7e96f3fe14fea5b6c3bbc7964863))
* **vscode:** support fileLocation in problemMatcher ([058177d](https://github.com/stevearc/overseer.nvim/commit/058177d3ae46342cd8b604894b44c206047dbac9))
* watch action prompts for all params ([c46fe9c](https://github.com/stevearc/overseer.nvim/commit/c46fe9c7d79e06bf76983170d61417ccf4a68cd3))


### Bug Fixes

* add a buffer valid guard ([#39](https://github.com/stevearc/overseer.nvim/issues/39)) ([7c8cc49](https://github.com/stevearc/overseer.nvim/commit/7c8cc498ac8526708ac8190a57012e3fdc0dda8d))
* add a win_is_valid guard ([a488c5c](https://github.com/stevearc/overseer.nvim/commit/a488c5ccdeb5afc94dbb9fd96214ce1fa478f9a5))
* add compatibility for neotest test file run ([1489a82](https://github.com/stevearc/overseer.nvim/commit/1489a826e75fd640690ba927bf109c6799c8489e))
* add more problem matchers from VS Code ([#160](https://github.com/stevearc/overseer.nvim/issues/160)) ([9925125](https://github.com/stevearc/overseer.nvim/commit/99251259db4d36ff3160d25403ec47f3af28ec00))
* add workaround to terminal update delay ([92e4ba8](https://github.com/stevearc/overseer.nvim/commit/92e4ba8d51191365e1da63f1f1f0e48efbd4ada7))
* always scroll to end of output when opening task buffer ([ce353ba](https://github.com/stevearc/overseer.nvim/commit/ce353ba0868e53b67d3d62a0a3dbd5e77cd3c40c))
* apply requested changes ([aacfe5d](https://github.com/stevearc/overseer.nvim/commit/aacfe5d0ec8af0716bc8b54343d8f3b7dd73f782))
* apply stylua ([93fb96a](https://github.com/stevearc/overseer.nvim/commit/93fb96a5e4c60f16313eca67e3d3284babbc674d))
* azure func tasks use port from launch.json ([#99](https://github.com/stevearc/overseer.nvim/issues/99)) ([65663ae](https://github.com/stevearc/overseer.nvim/commit/65663aedb76779ee6daa6f0a89806ac2474c2fba))
* bad call to vim.tbl_map ([1c74fbe](https://github.com/stevearc/overseer.nvim/commit/1c74fbe70b2b78894db6083a880f79dd666943e5))
* bad fileLocation value 'autodetect' -&gt; 'autoDetect' ([#125](https://github.com/stevearc/overseer.nvim/issues/125)) ([1dcbded](https://github.com/stevearc/overseer.nvim/commit/1dcbded930d4a954e07d0f0873940ec91a366c6e))
* better error message when VS Code task is missing type ([#118](https://github.com/stevearc/overseer.nvim/issues/118)) ([835514f](https://github.com/stevearc/overseer.nvim/commit/835514f9cd5fa92d3fd8c545035f7ac53da8c54b))
* better error messages in parser debugger when something is wrong ([2bf9481](https://github.com/stevearc/overseer.nvim/commit/2bf94810c82c66430df2cb04b2e3a3b226eb5f23))
* better workarounds for tailing terminal output ([c955e07](https://github.com/stevearc/overseer.nvim/commit/c955e07d0626d67a96156e1b8c931ea72bf08e4d))
* bug deserializing saved task strategy ([992e327](https://github.com/stevearc/overseer.nvim/commit/992e327b3ea0ce86de0808b906d4a1d5f3e7e940))
* bug determining when to open task launcher ([5171571](https://github.com/stevearc/overseer.nvim/commit/5171571beded63b8551efcdb77d176d343c7be25))
* bug in display_duration with tasks that soft reset ([844d59f](https://github.com/stevearc/overseer.nvim/commit/844d59f014faa037598aa4d00a08640f58d31390))
* bug in hook utils adding/removing components ([9eb40e2](https://github.com/stevearc/overseer.nvim/commit/9eb40e2ca8d73086e49b07e7f2d981fa725c9aa7))
* bug when specifying components using neotest strategy spec ([2a77a24](https://github.com/stevearc/overseer.nvim/commit/2a77a24f1402eaa0660dc9b256d426c0b648df46))
* bug with task buffer replacement on restart ([e2390f6](https://github.com/stevearc/overseer.nvim/commit/e2390f6018c1c59c6ca6b6baf301e1f9e02f14f4))
* bugs with Neotest stop and attach ([6688ad9](https://github.com/stevearc/overseer.nvim/commit/6688ad94be2cdac4262df3c301db98e81cf0eb61))
* capturing output from toggleterm ([#113](https://github.com/stevearc/overseer.nvim/issues/113)) ([ca30db0](https://github.com/stevearc/overseer.nvim/commit/ca30db070744f3c768aef3b1bd9849e2e870b797))
* cargo tasks parse relative paths from root ([#131](https://github.com/stevearc/overseer.nvim/issues/131)) ([9f67491](https://github.com/stevearc/overseer.nvim/commit/9f6749171ceac59af64c1c4ddab5176d6a9c5364))
* cargo templates ([#116](https://github.com/stevearc/overseer.nvim/issues/116)) ([34ac349](https://github.com/stevearc/overseer.nvim/commit/34ac349d650bb54adc609b05385a9c3c2fd59079))
* cargo templates search relative to current file before current dir ([#83](https://github.com/stevearc/overseer.nvim/issues/83)) ([e19fbd3](https://github.com/stevearc/overseer.nvim/commit/e19fbd3ee1ac28ab43aae6d193bfdde85403ca6c))
* check template condition when fetched by name ([#105](https://github.com/stevearc/overseer.nvim/issues/105)) ([2161232](https://github.com/stevearc/overseer.nvim/commit/21612328c18879096d8769749cf442d2b987088a))
* correct shell escaping for toggleterm strategy ([567e373](https://github.com/stevearc/overseer.nvim/commit/567e37305cb1f1031c931e765685f129892c3be3))
* dap session is started even on task failure if task has a matcher ([8d97030](https://github.com/stevearc/overseer.nvim/commit/8d97030bd5cc65e11c9dde4afed95d40c8b949ee))
* debug parser no overseer dir error ([056c2ee](https://github.com/stevearc/overseer.nvim/commit/056c2ee58b1433ba0f43c3d3825db7ac28f19b66))
* deno find file logic ([3abf750](https://github.com/stevearc/overseer.nvim/commit/3abf7503e22fa1fcc954ac8603d53b39b8a6543b))
* dependency tasks inherit cwd and env from parent ([b0e5067](https://github.com/stevearc/overseer.nvim/commit/b0e506700b76a05ac551ce1c143c9c0d9f1bf73c))
* deprecated treesitter API in nvim nightly ([cb05bcd](https://github.com/stevearc/overseer.nvim/commit/cb05bcd64760dc19c7ac712fb50118b04f2f7502))
* dispatch parser bug in debug mode ([744fe7f](https://github.com/stevearc/overseer.nvim/commit/744fe7f15582f1d1d3876806a07be99f7bec308a))
* **docs:** align tutorials.md with the current specs ([8070cdf](https://github.com/stevearc/overseer.nvim/commit/8070cdf468ec2b7ef80a47bb524b889f032ae92e))
* don't auto-add on_result_diagnostics to VS Code tasks ([#163](https://github.com/stevearc/overseer.nvim/issues/163)) ([15aa94e](https://github.com/stevearc/overseer.nvim/commit/15aa94ec1c8133e967171d353d9be45b4d9feea7))
* don't error on SessionSavePre when not using vim-session ([#112](https://github.com/stevearc/overseer.nvim/issues/112)) ([0f31de9](https://github.com/stevearc/overseer.nvim/commit/0f31de995fa4665027e1f755e0ce2d23e94a1023))
* don't run postDebugTask when it's nil ([#8](https://github.com/stevearc/overseer.nvim/issues/8)) ([2030fc1](https://github.com/stevearc/overseer.nvim/commit/2030fc13afcad0f6c8137cb8283a4fb9a53851c4))
* don't save orchestrator child tasks ([5ae185c](https://github.com/stevearc/overseer.nvim/commit/5ae185c54a20370c238afff0dafc08656a0aaccd))
* duplicate calls to on_init ([70df32b](https://github.com/stevearc/overseer.nvim/commit/70df32b79c162742bbf0940edcf3049d424b69cd))
* edge case crash when passing action to run_template ([44d2b6e](https://github.com/stevearc/overseer.nvim/commit/44d2b6e78decba807f007d992c87354871b47e3b))
* ensure all task processes are killed on exit ([#46](https://github.com/stevearc/overseer.nvim/issues/46)) ([d9e63c3](https://github.com/stevearc/overseer.nvim/commit/d9e63c3e387d6acac9fb08643ce26c4686eb5c30))
* error parsing vpath line in Makefile output ([#145](https://github.com/stevearc/overseer.nvim/issues/145)) ([1a7d89c](https://github.com/stevearc/overseer.nvim/commit/1a7d89cc1ae61199b227a15f077b3a9ca1da2dfa))
* error when running Neotest tests ([fc55888](https://github.com/stevearc/overseer.nvim/commit/fc558886428397f34f6e1649bb2f7713cd062f12))
* exclude .PHONY target in makefiles ([9473677](https://github.com/stevearc/overseer.nvim/commit/9473677696ab288ef74cb5a115338f39fbf740e5))
* exclude dependency tasks from bundles ([9c5c246](https://github.com/stevearc/overseer.nvim/commit/9c5c2463bb0be1612685e9d91b5790723c6c9d51))
* form help dialog does not close form ([10fb196](https://github.com/stevearc/overseer.nvim/commit/10fb196cc57e54efa858f91a919223df23ecc383))
* gracefully degrade make tasks when parser is missing ([dd6e22e](https://github.com/stevearc/overseer.nvim/commit/dd6e22e8aacfa993b064adf002bd4609392e4992))
* handle edge cases in previewing new tasks ([ebf0f8d](https://github.com/stevearc/overseer.nvim/commit/ebf0f8d8e6237d9737758af547dd154f21d63d5c))
* hide "Process exited" from output summary ([#26](https://github.com/stevearc/overseer.nvim/issues/26)) ([b10154a](https://github.com/stevearc/overseer.nvim/commit/b10154a64cd808b351c8ff6ebf7c96926f7dfedf))
* hide opaque types in task launcher ([7e66b81](https://github.com/stevearc/overseer.nvim/commit/7e66b811a6b0b18f0d1ca5b9e96be292ec8bc233))
* improve highlighting for parser debugger ([296c184](https://github.com/stevearc/overseer.nvim/commit/296c1843bc118210618e2a3a299c04ce5b2fe1db))
* improve nvim-cmp completion in form window ([eac76dc](https://github.com/stevearc/overseer.nvim/commit/eac76dcc7b4d0fef78e39641279f87c11dc22d89))
* incorrect check for composer.json file ([97cef92](https://github.com/stevearc/overseer.nvim/commit/97cef9258276da49771662a68979c12ec99345bc))
* infinite daprun callback loop for non-background tasks with problemMatcher ([9e4d72f](https://github.com/stevearc/overseer.nvim/commit/9e4d72fc0ade0fd5964c258ec7883c19238f36d6))
* inverted logic to block on_exit in VimLeavePre ([#55](https://github.com/stevearc/overseer.nvim/issues/55)) ([3854879](https://github.com/stevearc/overseer.nvim/commit/3854879aa7081474085926d93f8a899546565d6d))
* is_subpath is incorrect if paths are the same ([24e7f09](https://github.com/stevearc/overseer.nvim/commit/24e7f09acd0a3c8659a4a179541a23cbac550c4d))
* is_subpath logic checks path breaks ([#139](https://github.com/stevearc/overseer.nvim/issues/139)) ([9e7cc43](https://github.com/stevearc/overseer.nvim/commit/9e7cc435c1c85d37aa5471d7429501690f4d64d6))
* job ID registration in terminal strategy ([1242a53](https://github.com/stevearc/overseer.nvim/commit/1242a5347170bc59956657e40de4998edb2bc3e7))
* json decode error for trailing commas ([901da13](https://github.com/stevearc/overseer.nvim/commit/901da1301fd60c92972173e9466a358cba5174fd))
* just template handling of recipe with varargs ([82fcd8c](https://github.com/stevearc/overseer.nvim/commit/82fcd8c3b76df0a231a19d2739aa22bb5b6e24ac))
* link to actions.lua in the README ([38cbe13](https://github.com/stevearc/overseer.nvim/commit/38cbe135f2fc028353ee39cc33391e68a1773f2f))
* luacheck error ([d37b6c1](https://github.com/stevearc/overseer.nvim/commit/d37b6c150e4f2ba624a10f39a2fa780af54c2b52))
* luacheck errors ([70f79f8](https://github.com/stevearc/overseer.nvim/commit/70f79f878ee7ae20fb76022b713f3abbad2bf7eb))
* luacheck warnings ([97e695d](https://github.com/stevearc/overseer.nvim/commit/97e695dff19f9f664403397c41220d6fd960d3b5))
* make is_subpath case insensitive on windows ([#132](https://github.com/stevearc/overseer.nvim/issues/132)) ([211242a](https://github.com/stevearc/overseer.nvim/commit/211242ad352634e1bcb04346612181d01db42112))
* make it easier to delete a single item in a list ([480444c](https://github.com/stevearc/overseer.nvim/commit/480444c1d4fd7bbbd1e2f31716ed0f2eac6f0c3c))
* make toggleterm terminal window close when task resets ([65ac330](https://github.com/stevearc/overseer.nvim/commit/65ac330d4275c51f6deede8af1af4044a9fab967))
* mix tasks should generally prompt user for args ([2a922ba](https://github.com/stevearc/overseer.nvim/commit/2a922badb059f7e45a4075e967b8ce17352acbfd))
* neotest consumer fallback to run consumer ([#53](https://github.com/stevearc/overseer.nvim/issues/53)) ([5f16178](https://github.com/stevearc/overseer.nvim/commit/5f16178372fe24d5afa7f5cb871c5a86548e886b))
* neotest consumer respects default_strategy ([#93](https://github.com/stevearc/overseer.nvim/issues/93)) ([cebb263](https://github.com/stevearc/overseer.nvim/commit/cebb263509fa6cb52c63544845a721dd826b3c15))
* neotest tasks get excluded from task bundles by default ([041dcba](https://github.com/stevearc/overseer.nvim/commit/041dcbaca67b7e1d5e7404d5edbdc5c3e39087f9))
* nicer formatting and keybinds for :OverseerInfo win ([a17547a](https://github.com/stevearc/overseer.nvim/commit/a17547aaa61541f9c8623974e18d6933f87396e0))
* no error message for empty problemMatcher ([#103](https://github.com/stevearc/overseer.nvim/issues/103)) ([1cb7e41](https://github.com/stevearc/overseer.nvim/commit/1cb7e4128fb71be0f834c5aea6da7805010ab94c))
* numerous bugs with orchestrator and clean up code ([3411bd4](https://github.com/stevearc/overseer.nvim/commit/3411bd442b69cf3540fc053142759d7155fd0e32))
* on_output_summarize ignores all empty lines at the end ([52149b7](https://github.com/stevearc/overseer.nvim/commit/52149b77c99f50569e14a90b6495e3b3013255f7))
* only use reattach-to-user-namespace on mac when present ([d091d03](https://github.com/stevearc/overseer.nvim/commit/d091d033b6a56003a28c255ac7685ba04f754c96))
* output summarization fails for first few lines ([123603e](https://github.com/stevearc/overseer.nvim/commit/123603ecc2d4676b001351a6bb04b0def475ac53))
* OverseerQuickAction supports action name when task list not focused ([62ce37e](https://github.com/stevearc/overseer.nvim/commit/62ce37e8b805a12dfa94630f0b77735e830cbde3))
* parse quickfix items in cwd of task ([#59](https://github.com/stevearc/overseer.nvim/issues/59)) ([42c89a2](https://github.com/stevearc/overseer.nvim/commit/42c89a24c5f3dc13067fa4aee3467cc51125b531))
* parse relative filenames relative to task cwd ([5092582](https://github.com/stevearc/overseer.nvim/commit/5092582feb8376d8ed3bad426519ee04522ec1b8))
* parser debugger maintains input line number ([c70a12e](https://github.com/stevearc/overseer.nvim/commit/c70a12e2be55849a1b9908fb889869c56215245e))
* parser node test not respecting regex option ([886f8c4](https://github.com/stevearc/overseer.nvim/commit/886f8c4fb1658bba9c8a9f74205f629fd8d3c493))
* parser.lib.watcher_output got stuck ([247b931](https://github.com/stevearc/overseer.nvim/commit/247b931a0197204952c22510f92ca2716cb276a6))
* preferred width calculation for forms ([fbb8514](https://github.com/stevearc/overseer.nvim/commit/fbb851439242e8a0a94f1549e246baf2a2b4a8b0))
* preview window respects task_win config ([533b3cb](https://github.com/stevearc/overseer.nvim/commit/533b3cb2e4001597e6fc64c75d02667a73ff3106))
* relative filename parsing in on_output_quickfix ([61268c6](https://github.com/stevearc/overseer.nvim/commit/61268c60137bc6b09e15fee4e0806ad5c5e9823a))
* remove newlines from task names ([33453d3](https://github.com/stevearc/overseer.nvim/commit/33453d308c3a7abdb283bb772b708f67584b4644))
* remove unnecessary recoloring of lualine ([9812557](https://github.com/stevearc/overseer.nvim/commit/981255799a43e9855fc559f5dfa6b21b1a26854e))
* rerun neotest nearest from different buffer ([08f4780](https://github.com/stevearc/overseer.nvim/commit/08f47806ec3823aeb2b952d6f0a0afa9829475ab))
* restarting a task with dependencies restarts the dependencies ([5f02627](https://github.com/stevearc/overseer.nvim/commit/5f02627b8f5a9e5fb089689868c40dbde111b7e4))
* restore cursor to original window on close ([#136](https://github.com/stevearc/overseer.nvim/issues/136)) ([c63c60b](https://github.com/stevearc/overseer.nvim/commit/c63c60b0910dc556995f235919010928167db5a6))
* search for tasks relative to open file ([50c506f](https://github.com/stevearc/overseer.nvim/commit/50c506fc245dace4b1b3b8251762b6a14971b5f4))
* set noautocmd=true when opening task preview ([c17a278](https://github.com/stevearc/overseer.nvim/commit/c17a27821396d76d1ac5759ccefaa000f10d534d))
* setup opts arg should be optional ([28952e1](https://github.com/stevearc/overseer.nvim/commit/28952e189cb418d0b38efed022e76caecf862369))
* show OverseerRun errors to user ([#105](https://github.com/stevearc/overseer.nvim/issues/105)) ([859270c](https://github.com/stevearc/overseer.nvim/commit/859270c1afa90eeb9ad887ed097f01e154a98065))
* shrink size of preview window to not cover statusline ([3c0bc50](https://github.com/stevearc/overseer.nvim/commit/3c0bc50a09b031b5a8be676aedb9a56040b51361))
* some edge case errors when clearing parser results ([e277916](https://github.com/stevearc/overseer.nvim/commit/e277916b4555b5fa0fcb8904bc75aa550b06bf1f))
* stop using vim.wo to set window options ([80b67dd](https://github.com/stevearc/overseer.nvim/commit/80b67ddc9f60ab49c9606ca946776fce5cc91a06))
* task dependencies with multiple of the same task name ([21db618](https://github.com/stevearc/overseer.nvim/commit/21db6189a06af0c9ec9f11dbe1f3eb94df454034))
* task with dependencies disposes deps when disposed ([e3d534e](https://github.com/stevearc/overseer.nvim/commit/e3d534e6eff1844cdc0ad82df93cdc98f15e5ddb))
* TaskUtil functions handle empty component list ([93f898e](https://github.com/stevearc/overseer.nvim/commit/93f898e57ebc9be9c812852623f0cbf403c5a286))
* template build opts missing search param ([#129](https://github.com/stevearc/overseer.nvim/issues/129)) ([fc0da15](https://github.com/stevearc/overseer.nvim/commit/fc0da15aae4f0a484f5c8197de47a2f38ba1d196))
* tests ([dcc779f](https://github.com/stevearc/overseer.nvim/commit/dcc779f62f9e36f16f96537fe7d0e32c616f06c1))
* toggleterm strategy respects task cwd ([#89](https://github.com/stevearc/overseer.nvim/issues/89)) ([4d8614e](https://github.com/stevearc/overseer.nvim/commit/4d8614e829d8702bff6e9a5279820dd60591d9c0))
* type annotations on clear_cache ([21dc240](https://github.com/stevearc/overseer.nvim/commit/21dc24083f73d0d7b40439eec90131c6c2f3208a))
* unique component replaces old buffers in windows ([898024a](https://github.com/stevearc/overseer.nvim/commit/898024a75828a94367be0b85e98802655b6bd9a5))
* update $msCompile pattern from upstream ([4f26366](https://github.com/stevearc/overseer.nvim/commit/4f26366465b4bbb559859f9af0ca545d77a8e9f8))
* update deprecated nerd font icons ([39af1e9](https://github.com/stevearc/overseer.nvim/commit/39af1e910fba6c9667de5b6231cb5732190af920))
* update template.list callsite to be async ([#31](https://github.com/stevearc/overseer.nvim/issues/31)) ([36180f8](https://github.com/stevearc/overseer.nvim/commit/36180f8bde15766d06d2a028fccbf72985e993f6))
* use .vscode/ to detect vscode workspaceFolder ([939f3e7](https://github.com/stevearc/overseer.nvim/commit/939f3e7ccaab6f9f89cf88d0a26794dfebc35f20))
* use more thorough shell escaping for toggleterm ([9de57c6](https://github.com/stevearc/overseer.nvim/commit/9de57c625fce4a810f07970bcf99e849149b893c))
* use parsed terminal output for summary component ([f0bda9d](https://github.com/stevearc/overseer.nvim/commit/f0bda9d0d1111986476f149f17f5f20f8a7d25fc))
* vim.json.decode callsites to use lua nil ([14e502e](https://github.com/stevearc/overseer.nvim/commit/14e502ee2391b085ed84b64affa3ff3f2eb7461f))
* VS Code only escape command if args are not empty ([#119](https://github.com/stevearc/overseer.nvim/issues/119)) ([4812fd3](https://github.com/stevearc/overseer.nvim/commit/4812fd3ddb24dc20845321f5969fc110ab3216e5))
* VS Code problemMatcher always converts numeric captures ([979f93c](https://github.com/stevearc/overseer.nvim/commit/979f93c57885739f1141e37542bad808a29f7a9a))
* VS Code problemMatcher supports 'character' field ([405cda9](https://github.com/stevearc/overseer.nvim/commit/405cda9462b757909dc9d0b40dd8906abca01180))
* VS Code tasks with no type (compound tasks) ([1331e28](https://github.com/stevearc/overseer.nvim/commit/1331e289d1e16b3d3c9deefea9897efd983568f8))
* vscode problem matcher resolve issue ([137ced9](https://github.com/stevearc/overseer.nvim/commit/137ced99b786354d75df0d561d7109a580032acd))
* VSCode variables support more characters and log when unsupported ([358f0e5](https://github.com/stevearc/overseer.nvim/commit/358f0e5bb8600316fc790bd400aa5a507290affd))


### Performance Improvements

* add lazy loading to neotest and resession integrations ([cfacda7](https://github.com/stevearc/overseer.nvim/commit/cfacda71f81f2b9c7647eb6f574f42a0919ee818))
* speed up Makefile parsing ([#69](https://github.com/stevearc/overseer.nvim/issues/69)) ([42512c7](https://github.com/stevearc/overseer.nvim/commit/42512c7dae86a56cac1f17d5895c76cbc2ce4306))


### Code Refactoring

* restart_on_save component param "path" -&gt; "paths" ([77abf96](https://github.com/stevearc/overseer.nvim/commit/77abf961e87b78dba5a839b542a7d3692c68398d))


### doc

* announce new requirement for Neovim 0.8+ ([cc9fa86](https://github.com/stevearc/overseer.nvim/commit/cc9fa8676cd9d0c8ef4bee0a2ec5425a788d8f81))
