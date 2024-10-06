# cav-repo

![Preview image](https://raw.malwarepad.com/cavos/images/cav-repo.png)

## What is this?
The repo for the cav package manager repository & build system. It will later be utilized by the cav package manager directly to install, manage and update packages.

## Installation
There's no need to install anything; it's actually discouraged. This program is supposed to work directly off this repository. The following should be enough to make it work:
```
chmod +x ./cav-repo.sh
./cav-repo.sh --help
```

> Protip: If you need this globally, you can create a symbolic link for `/usr/bin`

## "I got x error, how do I fix it??!"
If you're using this project, we expect you to be able to solve basic issues yourself. Please don't open issues regarding "command not found" type errors. Remember that this is intended to run on servers and won't be interacted by inexperienced users!

Most weird issues will be solvable via just throwing the whole `session/` folder out the window and re-building.

## Adding packages
Again this is a rather advanced project so you'll have to read source code in order to contribute. If you're interested, check how packages are defined in `pkgs/` and try to do one yourself. They have to *at least* run from a cavOS chroot!

## License
The license for this project is available on the [LICENSE](LICENSE) file.
