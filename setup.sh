#!/bin/bash
VSCODE_REPO="deb [arch=amd64] http://packages.microsoft.com/repos/vscode stable main"
VSCODE_REPO_PATH="/etc/apt/sources.list.d/vscode.list"

install () {
    echo "Installing/upgrading $1"
    apt-get upgrade "$1" -y &> /dev/null
}

add_vscode_repo () {
    if [[ ! -f $VSCODE_REPO_PATH ]]; then
        echo "Creating vscode repo file"
        curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
        mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
        echo $VSCODE_REPO >> $VSCODE_REPO_PATH
        apt-get update &> /dev/null
    else
        echo "SKIP: vscode repo file already exists"
    fi
}

pipinstall () {
    echo "Installing/upgrading $1"
    pip3 install "$1" --upgrade &> /dev/null
}

codeinstall () {
    code --list-extensions --user-data-dir /home/basecamp/.vscode | grep -i "$1" &> /dev/null
    if [[ $? == 1 ]]; then
        echo "Installing $1"
        code --user-data-dir /home/basecamp/.vscode --install-extension "$1" &> /dev/null 
    else
        echo "SKIP: $1 already installed"
    fi
}

install_node () {
    apt-cache show nodejs &> /dev/null
    if [[ $? == 100 ]]; then
        echo "Adding node repo"
        curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - &> /dev/null
    else
        echo "SKIP: node repo already added"
    fi

    echo "Installing/upgrading node"
    apt-get upgrade -y nodejs &> /dev/null
}

npm_install () {
    echo "Installing/upgrading $1"
    npm -g install "$1" --upgrade &> /dev/null
}

add_apt_updater_cronjob () {
    JOB="0 9 * * 2 apt-get update; apt-get upgrade -y"
    crontab -l | grep "apt-get update; apt-get upgrade -y" &> /dev/null
    if [[ $? == 1 ]]; then
        echo "Adding apt updater cronjob"
        echo "$JOB" | crontab -
    else
        echo "SKIP: apt updater cronjob already created"
    fi
}

add_pip_updater_cronjob () {
    JOB="0 9 * * * pip3 install --upgrade yapf pytest bcca flask django requests records"
    crontab -l | grep "pip3 install --upgrade yapf pytest" &> /dev/null
    if [[ $? == 1 ]]; then
        echo "Adding pip updater cronjob"
        printf "`crontab -l`\n$JOB\n" | crontab -
    else
        echo "SKIP: pip updater cronjob already created"
    fi
}

set_favorites () {
    echo "Configuring favorites bar"
    su basecamp -c "gsettings set org.gnome.shell favorite-apps \"['firefox.desktop', 'org.gnome.Terminal.desktop', 'code.desktop']\""
}

set_clock () {
    echo "Configuring clock"
    su basecamp -c "gsettings set org.gnome.desktop.interface clock-format '12h'"
    su basecamp -c "gsettings set org.gnome.desktop.datetime automatic-timezone true"
}

turn_off_python_bytecode() {
    grep "PYTHONDONTWRITEBYTECODE=1" /home/basecamp/.bashrc &> /dev/null
    if [[ $? == 1 ]]; then
        echo "Turning off Python Bytecode generation"
        echo "PYTHONDONTWRITEBYTECODE=1" >> /home/basecamp/.bashrc
    else
        echo "SKIP: Python Bytecode generation turned off already"
    fi
}

set_prompt () {
    LINE="PS1=\"${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\] \$ \""
    grep "^PS1=" /home/basecamp/.bashrc &> /dev/null
    if [[ $? == 1 ]]; then
        echo "Configuring prompt"
        echo "$LINE" >> /home/basecamp/.bashrc
    else
        echo "SKIP: prompt already configured"
    fi
}

set_git_commit_template () {
    echo "Configuring git commit template"
    git config --global commit.template "/home/basecamp/.config/git/commit_template"

    mkdir -p /home/basecamp/.config/git
    echo "<Short Header>" > /home/basecamp/.config/git/commit_template
    echo "" >> /home/basecamp/.config/git/commit_template
    echo "<Summary of work>" >> /home/basecamp/.config/git/commit_template
}

add_global_python_gitignore () {
    echo "Configuring git to ignore unwanted python files"
    git config --global core.excludefiles '/home/basecamp/.config/git/ignore'
    curl "https://raw.githubusercontent.com/github/gitignore/master/Python.gitignore" -s -o /home/basecamp/.config/git/ignore
}

hide_trash () {
    echo "Hiding trash bin"
    su basecamp -c "gsettings set org.gnome.nautilus.desktop trash-icon-visible false"
}


main () {
    install curl
    install git
    install exuberant-ctags

    add_vscode_repo
    install code

    install python3-pip
    pipinstall yapf
    pipinstall pytest
    pipinstall ptpython
    pipinstall bcca
    pipinstall flask
    pipinstall django
    pipinstall requests
    pipinstall records

    codeinstall ms-python.python
    codeinstall magicstack.magicpython
    codeinstall esbenp.prettier-vscode
    codeinstall streetsidesoftware.code-spell-checker

    install_node

    npm_install prettier
    npm_install jasmine

    configure_vscode

    add_apt_updater_cronjob
    add_pip_updater_cronjob

    set_favorites
    set_clock
    hide_trash

    turn_off_python_bytecode
    set_prompt

    set_git_commit_template

    add_global_python_gitignore
}

configure_vscode () {
    echo "Configuring vscode"
    CONFIG=`cat <<EOF
{
    "editor.fontSize": 15,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "files.insertFinalNewline": true,
    "files.exclude": {
        "**/.git": true,
        "**/.svn": true,
        "**/.hg": true,
        "**/CVS": true,
        "**/.DS_Store": true,
        "**/__pycache__": true,
        "**/.vscode": true,
        "**/.pytest_cache": true,
        "**/.mypy_cache": true,
        "**/*.pyc": true
    },
    "prettier.tabWidth": 4,
    "python.formatting.provider": "yapf",
    "python.linting.mypyEnabled": false,
    "python.linting.pylintEnabled": false,
    "python.pythonPath": "/usr/bin/python3",
    "python.unitTest.promptToConfigure": false,
    "python.unitTest.pyTestEnabled": true,
    "git.autofetch": true
}
EOF`

    echo $CONFIG > /home/basecamp/.config/Code/User/settings.json
}

main 
