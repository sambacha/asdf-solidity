<div align="center">

# asdf-solidity 

[solidity](https://github.com/ethereum/solidity) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

## Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Why?](#why)
- [Contributing](#contributing)
- [License](#license)

## Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `SVMRC`: set this environment variable in your shell config to load the correct version of solidity

## Overview 

```bash
svm --version
```

```bash
svm use 0.6.12
```

### nvm like commands 

```
$ cat .svmrc
> 0.7.12
```

## Install

Plugin:

```shell
asdf plugin add solidity
# or
asdf plugin add https://github.com/sambacha/asdf-solidity.git
```

#### solidity:

```shell
# Show all installable versions
asdf list-all solidity

# Install specific version
asdf install solidity latest

# Set a version globally (on your ~/.tool-versions file)
asdf global solidity latest

# Now solidity commands are available
svm --version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

## Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/sambacha/asdf-solidity/graphs/contributors)!

## License

See [LICENSE](LICENSE) © [the contributors](https://github.com/sambacha/)
