# Changelog

## [1.4.5](https://github.com/dpietersz/boxkit/compare/v1.4.4...v1.4.5) (2025-10-23)


### Bug Fixes

* test PAT-based release workflow ([1489635](https://github.com/dpietersz/boxkit/commit/14896350cdc0fbd57648f31bb6c7409daced2e0f))

## [1.4.4](https://github.com/dpietersz/boxkit/compare/v1.4.3...v1.4.4) (2025-10-23)


### Bug Fixes

* final test of tag trigger workflow ([df46230](https://github.com/dpietersz/boxkit/commit/df46230edf67deea663529c48d0850a977a7e016))
* test v1.4.4 release ([63fbb22](https://github.com/dpietersz/boxkit/commit/63fbb22000e4551539ed79eb7cabb31c18daeb2c))

## [1.4.3](https://github.com/dpietersz/boxkit/compare/v1.4.2...v1.4.3) (2025-10-23)


### Bug Fixes

* test tag trigger for build-containers workflow ([d608d43](https://github.com/dpietersz/boxkit/commit/d608d4340b8c98945bbdbfa2bb00fb7183dc3d79))

## [1.4.2](https://github.com/dpietersz/boxkit/compare/v1.4.1...v1.4.2) (2025-10-23)


### Bug Fixes

* test release workflow trigger ([e395bde](https://github.com/dpietersz/boxkit/commit/e395bde35538499bea206453260d9f0a2e468e3e))

## [1.4.1](https://github.com/dpietersz/boxkit/compare/v1.4.0...v1.4.1) (2025-10-23)


### Bug Fixes

* remove non-existent packages from dev-apps ([98f19cb](https://github.com/dpietersz/boxkit/commit/98f19cb284ae0b3ebd7feb5c9c3935821ed0f66e))

## [1.4.0](https://github.com/dpietersz/boxkit/compare/v1.3.0...v1.4.0) (2025-10-23)


### Features

* add espanso text expander to Fedora daily-driver ([713e542](https://github.com/dpietersz/boxkit/commit/713e5426f210fd24421b92590dcef65711a668ab))
* integrate dotfiles setup into container builds ([3589b3d](https://github.com/dpietersz/boxkit/commit/3589b3d238b409b1ae64c0cf85470da4e75e3dc5))


### Bug Fixes

* add COSIGN_PASSWORD environment variable for encrypted key decryption ([18c2ae5](https://github.com/dpietersz/boxkit/commit/18c2ae57f4b430c1715fd1f0c9cfeb39f6c9f90d))
* construct cosign image reference using registry and tag ([db78013](https://github.com/dpietersz/boxkit/commit/db780130ed8d3280f95f60d360e245552b9af829))
* improve cosign signing and fedora build robustness ([5bab779](https://github.com/dpietersz/boxkit/commit/5bab7794ab71768838b924550617256adea8f283))
* improve cosign signing error diagnostics ([89524df](https://github.com/dpietersz/boxkit/commit/89524df24c14ee1d80aef40e903842fbc89f6499))
* improve cosign signing with fallback image reference construction ([38930b0](https://github.com/dpietersz/boxkit/commit/38930b09569e47b86dfdd46da352d68f051e9d3d))
* improve error handling in Fedora build script ([b51be14](https://github.com/dpietersz/boxkit/commit/b51be14bc7817ba3108f6135a5ab93de7a7a6356))
* remove dotfiles setup from container build scripts ([a0b1518](https://github.com/dpietersz/boxkit/commit/a0b151822e87cd4c5db883eff7499a139d85fba2))
* resolve Arch package installation issues ([1519f72](https://github.com/dpietersz/boxkit/commit/1519f72e2906fb06a2502696dd65f20d0fed68e1))
* resolve Fedora package installation failures ([c8f2d33](https://github.com/dpietersz/boxkit/commit/c8f2d330a494c785435dd96007a67818783bc592))
* resolve remaining GitHub Actions build failures ([f456fa4](https://github.com/dpietersz/boxkit/commit/f456fa4ab3e72a40226fdec98bfcdd53e815d784))
* simplify cosign signing image reference construction ([4ee3f38](https://github.com/dpietersz/boxkit/commit/4ee3f38207381a84585db76a8ac73277b3ab0f7b))
* switch to AUR version of obsidian and add additional GUI applications ([17767e0](https://github.com/dpietersz/boxkit/commit/17767e0e6252d8e343198e3f759888b98655e4c9))
* use correct image reference format for cosign signing ([2932484](https://github.com/dpietersz/boxkit/commit/293248494c41adc82734a874abe4f1b8988b40ff))
* use registry-path output directly for cosign signing ([ca6e8c3](https://github.com/dpietersz/boxkit/commit/ca6e8c39411784fd69ca8cfc1ddff1d77c0c730c))
* use registry-paths output for cosign signing ([b7d0d2f](https://github.com/dpietersz/boxkit/commit/b7d0d2ffd51326c8c11e29291ae989e709cb1463))

## [1.3.0](https://github.com/dpietersz/boxkit/compare/v1.2.0...v1.3.0) (2025-10-22)


### Features

* add age package ([#30](https://github.com/dpietersz/boxkit/issues/30)) ([b0989a9](https://github.com/dpietersz/boxkit/commit/b0989a9f791771999c105122b64cbf8687574650)), closes [#29](https://github.com/dpietersz/boxkit/issues/29)
* add basic EditorConfig file ([8a43b35](https://github.com/dpietersz/boxkit/commit/8a43b3568de65be0b4970a4a2d485cbf268567d9))
* add bat and exa ([#27](https://github.com/dpietersz/boxkit/issues/27)) ([011241e](https://github.com/dpietersz/boxkit/commit/011241e4ac1fdee5f3fbe8b8321e44ba8a0cb561))
* add clipboard ([ebc22bf](https://github.com/dpietersz/boxkit/commit/ebc22bf72a10043ebec55c285dfe5274f1378cc5))
* add conventional commits linter and changelog generator ([#5](https://github.com/dpietersz/boxkit/issues/5)) ([0bc283d](https://github.com/dpietersz/boxkit/commit/0bc283d271878071ef50a413bab48f3bfc1ab312))
* add daily-driver containers and update build workflow ([e90c924](https://github.com/dpietersz/boxkit/commit/e90c9241c9718fb3eed13a534b171967bd2484d3))
* add dependabot for actions ([#18](https://github.com/dpietersz/boxkit/issues/18)) ([cc17ca5](https://github.com/dpietersz/boxkit/commit/cc17ca5202c1777d5e64799b00cb235b72027e24))
* add make ([#10](https://github.com/dpietersz/boxkit/issues/10)) ([0cb4b59](https://github.com/dpietersz/boxkit/commit/0cb4b59cdd98c47d2f6bfa21f801b99b045d5e40))
* add npm ([#8](https://github.com/dpietersz/boxkit/issues/8)) ([9f91bd0](https://github.com/dpietersz/boxkit/commit/9f91bd09272617c7b9203014222353265dc24947))
* add vimdiff ([#12](https://github.com/dpietersz/boxkit/issues/12)) ([cf4202f](https://github.com/dpietersz/boxkit/commit/cf4202f76752561d9b926c81933342a119e8a258))
* add wl-clipboard ([#16](https://github.com/dpietersz/boxkit/issues/16)) ([347647e](https://github.com/dpietersz/boxkit/commit/347647ea7f9f7bdb3b42d2a565df866f027a7ade))
* Create CODE_OF_CONDUCT.md ([#4](https://github.com/dpietersz/boxkit/issues/4)) ([f433b89](https://github.com/dpietersz/boxkit/commit/f433b89a1ed125c6c0a251c1eec60525cfe35820))
* New readme ([#89](https://github.com/dpietersz/boxkit/issues/89)) ([4ccb045](https://github.com/dpietersz/boxkit/commit/4ccb045c84e3de6ed2d3ca3fd97f08c4818f942e))
* nicer filter to allow commenting out apps ([#15](https://github.com/dpietersz/boxkit/issues/15)) ([61d3e33](https://github.com/dpietersz/boxkit/commit/61d3e330beb9c2a8bd557ef3872aa6595c76b1b2))
* Refactor to use scripts ([#88](https://github.com/dpietersz/boxkit/issues/88)) ([b115bfd](https://github.com/dpietersz/boxkit/commit/b115bfd1d21886124b60493009bb8a1e8da62413))
* Replace exa with eza ([#57](https://github.com/dpietersz/boxkit/issues/57)) ([34653a2](https://github.com/dpietersz/boxkit/commit/34653a2dde5b4e1cf895a2d65fc9168e064fa224))
* switch to alpine edge ([#22](https://github.com/dpietersz/boxkit/issues/22)) ([cf396c3](https://github.com/dpietersz/boxkit/commit/cf396c369ae8d8bb052df9b0c39d392f61b909ba))


### Bug Fixes

* add back the push trigger ([#93](https://github.com/dpietersz/boxkit/issues/93)) ([d8e441d](https://github.com/dpietersz/boxkit/commit/d8e441d157517bf80eb8f5c72bdf8a025c440bc5))
* Cleanup fedora-example and packages/ ([040ab26](https://github.com/dpietersz/boxkit/commit/040ab262f71a586088a227583b22ca1c259ab907))
* container signing ([#55](https://github.com/dpietersz/boxkit/issues/55)) ([9b695c1](https://github.com/dpietersz/boxkit/commit/9b695c1a21a94e7b6a40f5175408b8fc650e9413))
* Correct fedora-example and clean packages/ ([b148eea](https://github.com/dpietersz/boxkit/commit/b148eea6d158e2c663a72cf274a180eee91b2c8a))
* correct fedora-example build ([5df5279](https://github.com/dpietersz/boxkit/commit/5df52797c8d62b1d37c1b12d0637b0fc221731f2))
* correct fedora-example build ([f9fe541](https://github.com/dpietersz/boxkit/commit/f9fe541f82bdfda5509f7b8c1d5a782e283c3b50))
* fix typo ([8addf9e](https://github.com/dpietersz/boxkit/commit/8addf9e4499a83b2b9b591e9808470f3e3f6a46e))
* remove neofetch ([#84](https://github.com/dpietersz/boxkit/issues/84)) ([ece0ab6](https://github.com/dpietersz/boxkit/commit/ece0ab62a72200683246a9b184d87f7def6872a5))
* resolve GitHub Actions build failures ([a12b65d](https://github.com/dpietersz/boxkit/commit/a12b65d92c2fb1782da45076181c8729c0429338))
* update cosign.pub ([#74](https://github.com/dpietersz/boxkit/issues/74)) ([5cb87a3](https://github.com/dpietersz/boxkit/commit/5cb87a3843be43ba5999c44006df83a09386ac59))
* update dependabot ([#19](https://github.com/dpietersz/boxkit/issues/19)) ([0c388c9](https://github.com/dpietersz/boxkit/commit/0c388c958985cdc7d3c2d3de5d6d58de09472edf))
* Update example toolboxes link in README.md ([#71](https://github.com/dpietersz/boxkit/issues/71)) ([11e0e81](https://github.com/dpietersz/boxkit/commit/11e0e81e3357638fa675dc6bbf06ab5443076c24))
* update maintainer field ([#37](https://github.com/dpietersz/boxkit/issues/37)) ([e94a8a6](https://github.com/dpietersz/boxkit/commit/e94a8a69c34f5692514ebcc8c3ac21e2f33aa947))

## [1.2.0](https://github.com/ublue-os/boxkit/compare/v1.1.0...v1.2.0) (2025-01-04)


### Features

* New readme ([#89](https://github.com/ublue-os/boxkit/issues/89)) ([4ccb045](https://github.com/ublue-os/boxkit/commit/4ccb045c84e3de6ed2d3ca3fd97f08c4818f942e))
* Refactor to use scripts ([#88](https://github.com/ublue-os/boxkit/issues/88)) ([b115bfd](https://github.com/ublue-os/boxkit/commit/b115bfd1d21886124b60493009bb8a1e8da62413))


### Bug Fixes

* add back the push trigger ([#93](https://github.com/ublue-os/boxkit/issues/93)) ([d8e441d](https://github.com/ublue-os/boxkit/commit/d8e441d157517bf80eb8f5c72bdf8a025c440bc5))
* Cleanup fedora-example and packages/ ([040ab26](https://github.com/ublue-os/boxkit/commit/040ab262f71a586088a227583b22ca1c259ab907))
* remove neofetch ([#84](https://github.com/ublue-os/boxkit/issues/84)) ([ece0ab6](https://github.com/ublue-os/boxkit/commit/ece0ab62a72200683246a9b184d87f7def6872a5))
* update cosign.pub ([#74](https://github.com/ublue-os/boxkit/issues/74)) ([5cb87a3](https://github.com/ublue-os/boxkit/commit/5cb87a3843be43ba5999c44006df83a09386ac59))
* Update example toolboxes link in README.md ([#71](https://github.com/ublue-os/boxkit/issues/71)) ([11e0e81](https://github.com/ublue-os/boxkit/commit/11e0e81e3357638fa675dc6bbf06ab5443076c24))

## [1.1.0](https://github.com/ublue-os/boxkit/compare/v1.0.0...v1.1.0) (2023-10-09)


### Features

* add age package ([#30](https://github.com/ublue-os/boxkit/issues/30)) ([b0989a9](https://github.com/ublue-os/boxkit/commit/b0989a9f791771999c105122b64cbf8687574650)), closes [#29](https://github.com/ublue-os/boxkit/issues/29)
* add bat and exa ([#27](https://github.com/ublue-os/boxkit/issues/27)) ([011241e](https://github.com/ublue-os/boxkit/commit/011241e4ac1fdee5f3fbe8b8321e44ba8a0cb561))
* add clipboard ([ebc22bf](https://github.com/ublue-os/boxkit/commit/ebc22bf72a10043ebec55c285dfe5274f1378cc5))
* add dependabot for actions ([#18](https://github.com/ublue-os/boxkit/issues/18)) ([cc17ca5](https://github.com/ublue-os/boxkit/commit/cc17ca5202c1777d5e64799b00cb235b72027e24))
* add make ([#10](https://github.com/ublue-os/boxkit/issues/10)) ([0cb4b59](https://github.com/ublue-os/boxkit/commit/0cb4b59cdd98c47d2f6bfa21f801b99b045d5e40))
* add npm ([#8](https://github.com/ublue-os/boxkit/issues/8)) ([9f91bd0](https://github.com/ublue-os/boxkit/commit/9f91bd09272617c7b9203014222353265dc24947))
* add vimdiff ([#12](https://github.com/ublue-os/boxkit/issues/12)) ([cf4202f](https://github.com/ublue-os/boxkit/commit/cf4202f76752561d9b926c81933342a119e8a258))
* add wl-clipboard ([#16](https://github.com/ublue-os/boxkit/issues/16)) ([347647e](https://github.com/ublue-os/boxkit/commit/347647ea7f9f7bdb3b42d2a565df866f027a7ade))
* nicer filter to allow commenting out apps ([#15](https://github.com/ublue-os/boxkit/issues/15)) ([61d3e33](https://github.com/ublue-os/boxkit/commit/61d3e330beb9c2a8bd557ef3872aa6595c76b1b2))
* Replace exa with eza ([#57](https://github.com/ublue-os/boxkit/issues/57)) ([34653a2](https://github.com/ublue-os/boxkit/commit/34653a2dde5b4e1cf895a2d65fc9168e064fa224))
* switch to alpine edge ([#22](https://github.com/ublue-os/boxkit/issues/22)) ([cf396c3](https://github.com/ublue-os/boxkit/commit/cf396c369ae8d8bb052df9b0c39d392f61b909ba))


### Bug Fixes

* container signing ([#55](https://github.com/ublue-os/boxkit/issues/55)) ([9b695c1](https://github.com/ublue-os/boxkit/commit/9b695c1a21a94e7b6a40f5175408b8fc650e9413))
* fix typo ([8addf9e](https://github.com/ublue-os/boxkit/commit/8addf9e4499a83b2b9b591e9808470f3e3f6a46e))
* update dependabot ([#19](https://github.com/ublue-os/boxkit/issues/19)) ([0c388c9](https://github.com/ublue-os/boxkit/commit/0c388c958985cdc7d3c2d3de5d6d58de09472edf))
* update maintainer field ([#37](https://github.com/ublue-os/boxkit/issues/37)) ([e94a8a6](https://github.com/ublue-os/boxkit/commit/e94a8a69c34f5692514ebcc8c3ac21e2f33aa947))

## 1.0.0 (2023-02-04)


### Features

* add conventional commits linter and changelog generator ([#5](https://github.com/ublue-os/boxkit/issues/5)) ([0bc283d](https://github.com/ublue-os/boxkit/commit/0bc283d271878071ef50a413bab48f3bfc1ab312))
* Create CODE_OF_CONDUCT.md ([#4](https://github.com/ublue-os/boxkit/issues/4)) ([f433b89](https://github.com/ublue-os/boxkit/commit/f433b89a1ed125c6c0a251c1eec60525cfe35820))
