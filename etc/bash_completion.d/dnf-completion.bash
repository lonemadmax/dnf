# dnf completion                                          -*- shell-script -*-
#
# This file is part of dnf.
#
# Copyright 2013 (C) Elad Alfassa <elad@fedoraproject.org>
# Copyright 2014-2015 (C) Igor Gnatenko <i.gnatenko.brain@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301  USA

_dnf_helper()
{
    local helper=$( ${python_exec} -c "import dnf.cli; print('{}/completion_helper.py'.format(dnf.cli.__path__[0]))" )
    COMPREPLY+=( $( ${python_exec} ${helper} "$@" -d 0 -q -C 2>/dev/null ) )
}

_is_path()
{
    if [[ "$1" == \.* ]] || [[ "$1" == \/* ]] || [[ "$1" == ~* ]]; then
        return 0
    else
        return 1
    fi
}

_modified_sack()
{
    local arr=( "${!1}" )
    for i in "${arr[@]}"; do
        if [[ "$i" == --installroot* ]] || [[ "$i" == --enablerepo* ]] || [[ "$i" == --disablerepo* ]]; then
            return 0
        fi
    done
    return 1
}

_dnf()
{
    if [[ "$( readlink /usr/bin/dnf )" == "dnf-2" ]]; then
        local python_exec="python2"
    else
        local python_exec="python3"
    fi

    local cur prev words cword
    _init_completion -s || return

    local commandix command
    for (( commandix=1; commandix < cword; commandix++ )); do
        if [[ ${words[commandix]} != -* ]]; then
            if [[ ${words[commandix-1]} != -* ]]; then
                command=${words[commandix]}
            fi
            break
        fi
    done

    # How many'th non-option arg (1-based) for $command are we completing?
    local i nth=1
    for (( i=commandix+1; i < cword; i++ )); do
        [[ ${words[i]} == -* ]] || (( nth++ ))
    done

    case $prev in
        -h|--help|--version)
            return
            ;;
        -d|--debuglevel|-e|--errorlevel)
            COMPREPLY=( $( compgen -W '0 1 2 3 4 5 6 7 8 9 10' -- "$cur" ) )
            ;;
        --installroot)
            COMPREPLY=( $( compgen -d -- "$cur" ) )
            ;;
        --enablerepo)
            _dnf_helper repolist disabled "$cur"
            ;;
        --disablerepo)
            _dnf_helper repolist enabled "$cur"
            ;;
        *)
            ;;
    esac

    $split && return

    local comp
    local cache_file="/var/cache/dnf/packages.db"
    local sqlite3="sqlite3 -batch -init /dev/null"
    if [[ $command ]]; then

        case $command in
            install|update|upgrade|reinstall|info)
                if ! _is_path "$cur"; then
                    if [ -r $cache_file ] && ! _modified_sack words[@]; then
                        COMPREPLY=( $( compgen -W '$( $sqlite3 $cache_file "select pkg from available WHERE pkg LIKE \"$cur%\"" 2>/dev/null )' ) )
                    else
                        _dnf_helper $command "$cur"
                    fi
                fi
                ext='@(rpm)'
                ;;
            erase|remove|downgrade)
                if ! _is_path "$cur"; then
                    if [ -r $cache_file ] && ! _modified_sack words[@]; then
                        COMPREPLY=( $( compgen -W '$( $sqlite3 $cache_file "select pkg from installed WHERE pkg LIKE \"$cur%\"" 2>/dev/null )' ) )
                    else
                        _dnf_helper $command "$cur"
                    fi
                fi
                [[ "$command" == downgrade ]] && ext='@(rpm)' || ext='NULL'
                ;;
            list|clean|history)
                _dnf_helper $command "$prev" "$cur"
                ext='NULL'
                ;;
            help)
                case $nth in
                    1)
                        _dnf_helper _cmds "$cur"
                        ;;
                esac
                ext='NULL'
                ;;
            *)
                ext='NULL'
                ;;
        esac
        if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
            if [[ "$ext" != "NULL" ]]; then
                _filedir $ext
            fi
        fi
        return

    fi

    if [[ $cur == -* ]]; then
        COMPREPLY=( $( compgen -W '$( _parse_help "$1" )' -- "$cur" ) )
        [[ $COMPREPLY == *= ]] && compopt -o nospace
    elif [[ ! $command ]]; then
        [[ $prev != -* ]] && _dnf_helper _cmds "$cur"
    fi
} &&
complete -F _dnf -o filenames dnf dnf-2 dnf-3
