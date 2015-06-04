## Install

1. Clone this repository to your home directory.

```sh
git clone https://github.com/carlosV2/bash-dev-tools.git .bash-dev-tools
```

2. Modify your `~/.bashrc` and add to the end

```sh
# some other config in .bashrc

# bash dev tools configurations

# Enables the alias
ENABLE_ALIAS=true

# Enables the git tools
ENABLE_GIT=true

# Enables the symfony tools
ENABLE_SYMFONY=true

# Enables the symfony tools
ENABLE_BEHAT=true

# Enables the symfony tools
ENABLE_PHPSPEC=true

# Enables the vagrant tools
ENABLE_VAGRANT=true

# Specify the base path
# For example: /home/<user>/.bash-dev-tools/
BASE_PATH="<insert your full installation path here>"

# Source the bash dev tools script
source "${BASE_PATH}devtools.sh"
```

**Enjoy!**
