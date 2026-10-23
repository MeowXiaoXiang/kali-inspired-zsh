#!/usr/bin/env python3
"""Run on Linux/WSL: python3 tests/test_zsh.py. Uses disposable HOME/repos."""
import os
from pathlib import Path
import pty
import re
import select
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / '.zshrc'
SOURCE = CONFIG.read_text(encoding='utf-8')


class ZshTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='kali-zsh-test-')
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        TERM='xterm', LC_ALL='C.UTF-8', GIT_CONFIG_NOSYSTEM='1',
                        GIT_CONFIG_GLOBAL='/dev/null')
        self.config = CONFIG

    def variant(self, **settings):
        text = SOURCE
        for name, value in settings.items():
            text, count = re.subn(r'^' + name + r'="[^"]*"$',
                                  name + '="' + value + '"', text, flags=re.M)
            self.assertEqual(count, 1, name)
        self.config = self.home / 'variant.zsh'
        self.config.write_text(text, encoding='utf-8')

    def shell(self, script, interactive=True):
        code = 'source ' + shlex.quote(str(self.config)) + '\n' + script
        p = subprocess.run(['zsh', '-f', '-i' if interactive else '-c'] +
                           (['-c', code] if interactive else [code]),
                           cwd=self.home, env=self.env, text=True,
                           capture_output=True, timeout=25)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(p.stderr, '', p.stderr)
        return p.stdout

    def test_syntax_and_noninteractive(self):
        subprocess.run(['zsh', '-n', str(CONFIG)], check=True)
        self.shell('(( ! $+functions[set_zsh_prompt] ))', interactive=False)
        self.assertFalse((self.home / '.zsh').exists())

    def test_all_features_disabled(self):
        flags = re.findall(r'^(ENABLE_\w+)=', SOURCE, flags=re.M)
        self.variant(**dict.fromkeys(flags, 'N'))
        self.shell("[[ -n $PROMPT && $PROMPT != *exit:* ]] && "
                   "[[ $(bindkey '^R') == *history-incremental-search-backward* ]]")

    @unittest.skipUnless(os.environ.get('ZSH_TEST_PLUGIN_ROOT'),
                         'Set ZSH_TEST_PLUGIN_ROOT for real plugin integration')
    def test_installed_plugins(self):
        plugins = Path(os.environ['ZSH_TEST_PLUGIN_ROOT'])
        (self.home / '.zsh').mkdir()
        (self.home / '.zsh/plugins').symlink_to(plugins, target_is_directory=True)
        for name in ('zsh-autosuggestions', 'zsh-syntax-highlighting'):
            self.assertTrue((plugins / name / (name + '.zsh')).is_file())
        self.shell(r'''
(( $+functions[_zsh_autosuggest_start] && $+functions[_zsh_highlight] )) || exit 1
(( $+widgets[autosuggest-accept] )) || exit 2
[[ $(bindkey '^R') == *history-incremental-search-backward* ]] || exit 3
source "''' + str(CONFIG) + r'''"
[[ ${(M)#precmd_functions:#set_zsh_prompt} -eq 1 ]] || exit 4
[[ ${(M)#preexec_functions:#_preexec_timer} -eq 1 ]]
''')

    def test_local_overrides(self):
        (self.home / '.zsh_aliases').write_text("alias hello='print local'\n")
        (self.home / '.zsh_local').write_text(
            "PROMPT_HOST_SYMBOL='LOCAL'\nbindkey '^R' beginning-of-line\n")
        self.shell("[[ $PROMPT_HOST_SYMBOL == LOCAL && $aliases[hello] == 'print local' "
                   "&& $(bindkey '^R') == *beginning-of-line* ]]")

    @unittest.skipUnless(os.environ.get('ZSH_TEST_PLUGIN_ROOT'), 'Real plugins required')
    def test_plugin_switches_independent(self):
        (self.home / '.zsh').mkdir()
        (self.home / '.zsh/plugins').symlink_to(os.environ['ZSH_TEST_PLUGIN_ROOT'])
        self.variant(ENABLE_AUTOSUGGESTIONS='N')
        self.shell('(( ! $+functions[_zsh_autosuggest_start] && $+functions[_zsh_highlight] ))')
        self.variant(ENABLE_SYNTAX_HIGHLIGHTING='N')
        self.shell('(( $+functions[_zsh_autosuggest_start] && ! $+functions[_zsh_highlight] ))')

    def test_missing_extract_tool_hint(self):
        self.shell(r'''
path=()
_pkg_manager() { print apt; }
hint=$(_extract_need unxz 2>&1)
[[ $? == 1 && $hint == *'apt install xz-utils'* ]] || exit 1
hint=$(_extract_need gunzip 2>&1)
[[ $? == 1 && $hint == *'apt install gzip'* ]] || exit 2
_pkg_manager() { print dnf; }
hint=$(_extract_need unxz 2>&1)
[[ $? == 1 && $hint == *'dnf install xz'* ]]
''')

    def test_early_config_and_alias_defaults(self):
        (self.home / '.zsh_config').write_text('ENABLE_SMART_HISTORY="N"\nENABLE_TIMESTAMP="N"\n')
        self.shell(r'''
[[ $ENABLE_TIMESTAMP == N && $(bindkey '^[[A') != *history-search-backward* ]] || exit 1
[[ $aliases[ll] == 'ls -alF' && $aliases[la] == 'ls -A' && $aliases[l] == 'ls -CF' ]] || exit 2
[[ $aliases[aptup] == pkgup && -z $aliases[c] && -z $aliases[now] ]]
''')

    def test_package_routing_and_failure(self):
        self.shell(r'''
native=$(_pkg_manager)
[[ $native == apt || $native == dnf ]] || exit 1
sudo() { print -r -- "$*" >> "$HOME/pkgcalls"; }
pkgup
pkgclean
if [[ $native == apt ]]; then
    expected=$'apt update\napt upgrade\napt autoremove\napt clean'
else
    expected=$'dnf upgrade --refresh\ndnf autoremove\ndnf clean packages'
fi
[[ $(<"$HOME/pkgcalls") == "$expected" ]] || exit 2
for family in apt dnf; do
    _pkg_manager() { print -r -- "$family"; }
    sudo() { print -r -- "$*" >> "$HOME/failcalls"; return 9; }
    : > "$HOME/failcalls"
    pkgup
    [[ $? == 9 && $(wc -l < "$HOME/failcalls") -eq 1 ]] || exit 3
    : > "$HOME/failcalls"
    pkgclean
    [[ $? == 9 && $(wc -l < "$HOME/failcalls") -eq 1 ]] || exit 4
done
''')

    def test_extract_archives_and_collisions(self):
        import tarfile
        import zipfile
        import gzip
        import bz2
        import lzma
        payload = self.home / 'payload.txt'
        payload.write_text('original')
        for suffix, mode in (('tar', 'w'), ('tar.gz', 'w:gz'),
                             ('tar.bz2', 'w:bz2'), ('tar.xz', 'w:xz')):
            with tarfile.open(self.home / ('-archive.' + suffix), mode) as out:
                out.add(payload, arcname='payload.txt')
        with zipfile.ZipFile(self.home / '-archive.zip', 'w') as out:
            out.write(payload, 'payload.txt')
        for suffix, lib in (('gz', gzip), ('bz2', bz2), ('xz', lzma)):
            (self.home / ('-single.' + suffix)).write_bytes(lib.compress(b'original'))
        self.shell(r'''
for archive in -archive.tar -archive.tar.gz -archive.tar.bz2 -archive.tar.xz -archive.zip; do
    mkdir "out-$archive"
    (cd "out-$archive" && extract "../$archive") || exit 1
    [[ $(<"out-$archive/payload.txt") == original ]] || exit 2
    print protected > "out-$archive/payload.txt"
    (cd "out-$archive" && extract "../$archive") >/dev/null 2>&1
    [[ $(<"out-$archive/payload.txt") == protected ]] || exit 3
done
for archive in -single.gz -single.bz2 -single.xz; do
    mkdir "out-$archive"
    cp -- "$archive" "out-$archive/"
    (cd "out-$archive" && extract "$archive") || exit 4
    [[ $(<"out-$archive/-single") == original && -f "out-$archive/$archive" ]] || exit 5
    print protected > "out-$archive/-single"
    (cd "out-$archive" && extract "$archive") >/dev/null 2>&1
    [[ $(<"out-$archive/-single") == protected ]] || exit 6
done
extract >/dev/null 2>&1; [[ $? == 2 ]] || exit 7
extract nonexistent >/dev/null 2>&1; [[ $? == 1 ]] || exit 8
print invalid > corrupt.tar
extract corrupt.tar >/dev/null 2>&1; [[ $? != 0 ]]
''')

    def test_git_other_failure(self):
        self.shell(r'''
git init -q repo
cd repo
_git_status_porcelain() { return 128; }
get_git_info
[[ $_git_info_out == *' !' ]]
''')

    def test_path_components_unicode_and_narrow(self):
        self.shell(r'''
[[ $(_shorten_path_components /home/user/projects/backend/service 25) == '/home/…/backend/service' ]] || exit 1
[[ $(_shorten_path_components / 1) == / ]] || exit 2
[[ $(_shorten_path_components '~' 1) == '~' ]] || exit 3
[[ $(_shorten_path_components /超長的單一目錄名稱 2) == /超長的單一目錄名稱 ]] || exit 4
COLUMNS=15
set_zsh_prompt
[[ $PROMPT == *'┌──('* && $PROMPT == *'└─'* ]]
''')

    def test_cache_persists_and_expires(self):
        self.shell(r'''
git init -q repo
cd repo
calls=0
_git_status_porcelain() { (( calls++ )); print -r -- '?? new'; }
set_zsh_prompt
[[ $_git_cache_time -gt 0 && $_load_cache_time -gt 0 && -n $_path_info_out ]] || exit 1
[[ $PROMPT == *' ?'* ]] || exit 2
# Observe calls from the subshell through a file, not a shell variable.
_git_status_porcelain() { print call >> "$HOME/calls"; }
_git_cache_time=0
set_zsh_prompt
set_zsh_prompt
[[ $(wc -l < "$HOME/calls") -eq 1 ]] || exit 3
_git_cache_time=$(( EPOCHSECONDS - GIT_CACHE_TIMEOUT - 1 ))
set_zsh_prompt
[[ $(wc -l < "$HOME/calls") -eq 2 ]] || exit 4
ENABLE_GIT_INFO=N
set_zsh_prompt
[[ $PROMPT != *master* && $PROMPT != *main* ]]
''')

    def test_empty_load_is_cached(self):
        self.shell(r'''
_load_cache_time=0
_load_threshold() { print call >> "$HOME/loads"; print 999999; }
get_system_load
get_system_load
[[ -z $_load_info_out && $(wc -l < "$HOME/loads") -eq 1 ]]
''')

    def test_path_resize_and_options(self):
        self.shell(r'''
mkdir -p aaaaaaaaaaaaaaaaaaaa/bbbbbbbbbbbbbbbbbbbb/cccccccccccccccccccc
cd a*/b*/c*
COLUMNS=160
get_shortened_path
wide=$_path_info_out
COLUMNS=50
get_shortened_path
[[ ${#_path_info_out} -lt ${#wide} ]] || exit 1
PATH_MAX_LENGTH=24
COLUMNS=160
get_shortened_path
[[ $_path_info_out == *…* && $_path_info_out == *cccccccccccccccccccc ]] || exit 2
ENABLE_PATH_SHORTENING=N
get_shortened_path
[[ $_path_info_out == '%~' ]]
''')

    def test_external_prompt_text_is_literal(self):
        self.shell(r'''
mkdir -p 'dir%F{red}$(touch INJECTED)'
cd 'dir%F{red}$(touch INJECTED)'
git init -q
git symbolic-ref HEAD 'refs/heads/branch%F{blue}'
mkdir -p "$HOME/venv%F{yellow}"
VIRTUAL_ENV="$HOME/venv%F{yellow}"
PATH_MAX_LENGTH=200
COLUMNS=200
set_zsh_prompt
rendered=$(print -P -- "$PROMPT")
[[ $rendered == *'dir%F{red}$(touch INJECTED)'* &&
   $rendered == *'branch%F{blue}'* && $rendered == *'venv%F{yellow}'* ]] || exit 1
[[ ! -e INJECTED && ! -o PROMPT_SUBST ]] || exit 2
CONDA_DEFAULT_ENV='conda%F{red}'
unset VIRTUAL_ENV
set_zsh_prompt
[[ $(print -P -- "$PROMPT") == *'conda%F{red}'* ]]
''')

    def test_git_states(self):
        self.shell(r'''
GIT_CACHE_TIMEOUT=0
git init -q repo
cd repo
git config user.name Test
git config user.email test@example.invalid
git config commit.gpgsign false
print base > tracked
git add tracked
git commit -qm initial
branch=$(git branch --show-current)
get_git_info
[[ $_git_info_out == *"$branch%f" ]] || exit 1
print changed >> tracked
get_git_info
[[ $_git_info_out == *' *' ]] || exit 2
git add tracked
get_git_info
[[ $_git_info_out == *' +' ]] || exit 3
rm tracked
get_git_info
[[ $_git_info_out == *' *+' ]] || exit 4
git reset -q --hard HEAD
print new > untracked
get_git_info
[[ $_git_info_out == *' ?' ]] || exit 5
git stash push -qu
get_git_info
[[ $_git_info_out == *' $' ]] || exit 6
git checkout -q --detach
get_git_info
[[ $_git_info_out == *"$(git rev-parse --short HEAD)"* ]] || exit 7
git init -q --bare "$HOME/bare"
cd "$HOME/bare"
get_git_info
[[ -z $_git_info_out ]]
''')

    def test_branch_switch_same_commit(self):
        self.shell(r'''
git init -q repo
cd repo
git -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm initial --allow-empty
set_zsh_prompt
git checkout -qb other
set_zsh_prompt
[[ $PROMPT == *other* ]]
''')

    def test_git_merge_conflict(self):
        self.shell(r'''
GIT_CACHE_TIMEOUT=0
git init -q repo
cd repo
git config user.name Test
git config user.email test@example.invalid
git config commit.gpgsign false
print base > tracked
git add tracked
git commit -qm base
git checkout -qb side
print side > tracked
git commit -qam side
git checkout -qb other HEAD~1
print other > tracked
git commit -qam other
git merge side >/dev/null 2>&1 && exit 1
get_git_info
[[ $_git_info_out == *'[MERGE]'* && $_git_info_out == *' *+' ]]
''')

    def test_upstream_and_worktree_operations(self):
        self.shell(r'''
GIT_CACHE_TIMEOUT=0
git init -q repo
cd repo
git config user.name Test
git config user.email test@example.invalid
git config commit.gpgsign false
git commit -qm initial --allow-empty
git branch upstream
git branch --set-upstream-to=upstream >/dev/null
git commit -qm ahead --allow-empty
get_git_info
[[ $_git_info_out == *'↑1'* ]] || exit 1
git update-ref refs/heads/upstream HEAD
git reset -q --hard HEAD~1
get_git_info
[[ $_git_info_out == *'↓1'* ]] || exit 2
git worktree add -qb linked "$HOME/linked" >/dev/null
cd "$HOME/linked"
mkdir sub
cd sub
print "$(git rev-parse HEAD)" > "$(git rev-parse --git-path MERGE_HEAD)"
get_git_info
[[ $_git_info_out == *'[MERGE]'* ]]
''')

    def test_git_timeout_is_unknown(self):
        self.shell(r'''
git init -q repo
cd repo
GIT_STATUS_TIMEOUT=0.01
mkdir "$HOME/bin"
real_git=$(command -v git)
print -rl -- '#!/bin/sh' 'if [ "$1" = status ]; then sleep 1; fi' "exec $real_git \"\$@\"" > "$HOME/bin/git"
chmod +x "$HOME/bin/git"
path=("$HOME/bin" $path)
get_git_info
[[ $_git_info_out == *' ~' ]]
''')

    def test_missing_optional_commands(self):
        # Leave core Linux tools available, hide all optional integrations.
        bindir = self.home / 'minimal-bin'
        bindir.mkdir()
        for name in ('zsh', 'mkdir', 'mv', 'date', 'nproc', 'grep',
                     'uname', 'hostname', 'getent', 'ls', 'dircolors'):
            found = shutil.which(name)
            if found:
                (bindir / name).symlink_to(found)
        self.env['PATH'] = str(bindir)
        self.shell("(( ! $+commands[git] )) "
                   "&& [[ $(bindkey '^R') == *history-incremental-search-backward* ]] "
                   "&& [[ -n $PROMPT ]]")

    def test_real_interactive_status_and_timer(self):
        if os.environ.get('ZSH_TEST_PLUGIN_ROOT'):
            (self.home / '.zsh').mkdir()
            (self.home / '.zsh/plugins').symlink_to(
                os.environ['ZSH_TEST_PLUGIN_ROOT'], target_is_directory=True)
        master, slave = pty.openpty()
        proc = subprocess.Popen(['zsh', '-f', '-i'], stdin=slave, stdout=slave,
                                stderr=slave, env=self.env, cwd=self.home,
                                start_new_session=True)
        os.close(slave)

        def read_until_prompt(timeout=8):
            data = b''
            end = time.monotonic() + timeout
            while time.monotonic() < end:
                if select.select([master], [], [], 0.1)[0]:
                    data += os.read(master, 65536)
                    clean = re.sub(rb'\x1b\[[0-?]*[ -/]*[@-~]', b'', data)
                    if re.search(rb'\xe2\x94\x94\xe2\x94\x80[$#] $', clean):
                        return clean.decode(errors='replace')
            self.fail('No interactive prompt: ' + repr(data))

        try:
            os.write(master, ('source ' + shlex.quote(str(CONFIG)) + '\n').encode())
            read_until_prompt()
            for command, expected, absent in (
                ('false', 'exit:1', '3s'),
                ('true', None, 'exit:'),
                ("sh -c 'sleep 3; exit 7'", 'exit:7', None),
                ('false | true', None, 'exit:'),
            ):
                os.write(master, (command + '\n').encode())
                text = read_until_prompt()
                if expected:
                    self.assertIn(expected, text)
                if absent:
                    self.assertNotIn(absent, text)
                if 'sleep 3' in command:
                    self.assertRegex(text, r'\[[34]s\]')
        finally:
            if proc.poll() is None:
                os.write(master, b'exit\n')
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
            os.close(master)


class RepositoryFormatTests(unittest.TestCase):
    def test_utf8_lf(self):
        for name in ('.zshrc', '.gitattributes', '.editorconfig', '.gitignore', 'README.md',
                     'LICENSE', 'tests/test_zsh.py', 'docs/development.md',
                     'docs/usage.md', 'docs/configuration.md', 'docs/troubleshooting.md'):
            with self.subTest(file=name):
                data = (ROOT / name).read_bytes()
                self.assertFalse(data.startswith(b'\xef\xbb\xbf'))
                self.assertNotIn(b'\r', data)
                self.assertTrue(data.endswith(b'\n'))
                data.decode('utf-8')


if __name__ == '__main__':
    unittest.main(verbosity=2)
