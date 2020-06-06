#!/usr/bin/env sh

EXIT_CODE=0
HOOK_PATH=$(dirname "${0}")

#Check if we are in the middle of the merge if yes then bail out
[ -f "${HOOK_PATH}/../MERGE_HEAD" ] && exit ${EXIT_CODE}

CHECK_ALL_CHANGES=${CHECK_ALL_CHANGES:-}
if [ -z "${CHECK_ALL_CHANGES}" ]; then
  CHECK_FUNCTION=checkOnlyMyChanges
else
  CHECK_FUNCTION=checkAllChanges
fi

STANDARD='PSR12'
VENDOR_PATH='vendor/bin'

#If you have php locally
#PSR_CHECKER="${HOOK_PATH}/../../${VENDOR_PATH}/phpcs --standard=${STANDARD}"
#PSR_FIXER="${HOOK_PATH}/../../${VENDOR_PATH}/phpcbf --standard=${STANDARD}"
#PROJECT_PATH='<local_path_to_project>'

#If you run it on vagrant
VAGRANT_CONNECT='ssh -oPasswordAuthentication=no -p2222 vagrant@127.0.0.1'
PROJECT_PATH='/var/www/tubes'
PSR_CHECKER="${VAGRANT_CONNECT} ${PROJECT_PATH}/${VENDOR_PATH}/phpcs --standard=${STANDARD}"
PSR_FIXER="${VAGRANT_CONNECT} ${PROJECT_PATH}/${VENDOR_PATH}/phpcbf --standard=${STANDARD}"

fixFile()
{
  ${PSR_FIXER} "${PROJECT_PATH}/${1}"
}

fixAndUpdateCommit()
{
  fixFile "${1}"
  git add -u "${1}"
}

checkAllChanges()
{
  fixable=$(echo "${2}" | grep -c '| \[x\]')
  #Nothing is fixable don't run phpcbf just show phpcs output
  if [ "${fixable}" = 0 ]; then
    echo "${2}"

    return 1
  fi

  notFixable=$(echo "${2}" | grep -c '| \[ \]')
  #Everything is fixable so fix file and update it for commit
  if [ "${notFixable}" = 0 ]; then
    fixAndUpdateCommit "${1}"

    return 0
  fi

  #Something is fixable run phpcbf, show phpcs output for reference
  echo "${2}"
  fixFile "${1}"

  return 1
}

checkAndOutputUserErrors()
{
  userChangedLines=$(gitDiffToChangedLines "${1}")
  exitCode=0
  outputError=0
  newLine="File: ${1}\n"
  while read -r line; do
    nonFixableLineNum=$(echo "${line}" | awk -F'|' '{print $1}' | sed 's/ //g')
    #Check if there were line breaks and we want to show it
    if [ -z "${nonFixableLineNum}" ] && [ "${outputError}" = 1 ]; then
      echo "${line}" | awk -F'|' '{printf $3}'
    elif [ -n "${nonFixableLineNum}" ]; then
      #Check if non fixable line is one of the user changes
      if echo "${userChangedLines}" | grep -q "\b${nonFixableLineNum}\b"; then
        printf "${newLine}%s" "${line}"
        outputError=1
        newLine='\n'
        exitCode=1
      else
        outputError=0
      fi
    fi
  done

  return ${exitCode}
}

checkOnlyMyChanges()
{
  #We need to check are there any fixable errors if not phpcs wont output boxes
  fixable=$(echo "${2}" | grep -c '| \[x\]')
  if [ "${fixable}" = 0 ]; then
    nonFixablePattern='|'
  else
    nonFixablePattern='| \[ \]'
  fi
  notFixable=$(echo "${2}" | grep -c "${nonFixablePattern}")

  outputError=0
  newLine=
  #Get non fixable errors and check if user changes are one of them
  echo "${2}" | grep "${nonFixablePattern}" | checkAndOutputUserErrors "${1}"
  exitCode=$?

  #Nothing is fixable so just return exitCode
  if [ "${fixable}" = 0 ]; then
    return ${exitCode}
  fi

  #Everything is fixable or we are still going to commit
  if [ "${notFixable}" = 0 ] || [ "${exitCode}" = 0 ]; then
    fixAndUpdateCommit "${1}"

    return ${exitCode}
  fi

  fixFile "${1}"

  return ${exitCode}
}

max()
{
  if [ "${1}" -gt "${2}" ]; then
    echo "${1}"
  else
    echo "${2}"
  fi
}

gitDiffToChangedLines()
{
  #Store file diff since we will parse output many times
  fileDiff=$(git diff --cached --no-color --word-diff=plain "${1}")

  #Find hunk headers in diff with corresponding line
  echo "${fileDiff}" | grep -ne '^@@.*@@' | sed 's/^\(.*\):@@ \(.*\) @@\(.*\)/\1:\2/g' |
    while read -r meta; do
      startingLineInDiff=$(echo "${meta}" | awk -F: '{print $1}')
      hunk=$(echo "${meta}" | awk -F: '{print $2}')
      previous=$(echo "${hunk}" | awk '{print $1}')
      current=$(echo "${hunk}" | awk '{print $2}')
      linesToRead=$(max "$(echo "${previous}" | awk -F, '{print $2}')" "$(echo "${current}" | awk -F, '{print $2}')")
      lineNum=$(echo "${current}" | awk -F, '{print $1}' | sed 's/+//g')
      #Read code lines corresponding to this hunk
      echo "${fileDiff}" | tail +$((startingLineInDiff + 1)) | head -"${linesToRead}" |
        while read -r line; do
          #Check if line was deleted if yes skip it
          if echo "${line}" | grep -qe '^\[-.*-\]$'; then
            continue
          fi
          #Check if user have changed this line
          if echo "${line}" | grep -q -e '\[-.*-\]' -e '\{+.*+\}'; then
            echo "${lineNum}"
          fi
          lineNum=$((lineNum + 1))
        done
    done
}

#Main checking loop
for file in $(git diff --cached --name-only --diff-filter=d | grep '.php$'); do
  if [ -n "$(git diff --name-only "${file}")" ]; then
    echo "File [${file}] has changes not staged for commit. Stash them or add them to commit"
    EXIT_CODE=$((EXIT_CODE + 1))
    continue
  fi

  snifferOutput=$(${PSR_CHECKER} "${PROJECT_PATH}/${file}")
  snifferReturn=$?
  #Everything is fine
  if [ "${snifferReturn}" = 0 ]; then
    continue
  fi

  ${CHECK_FUNCTION} "${file}" "${snifferOutput}"
  EXIT_CODE=$((EXIT_CODE + $?))
done

#Check if HEAD still has changes
CNT_FILES_TO_COMMIT=$(git diff --cached --name-only | wc -l)

if [ "${CNT_FILES_TO_COMMIT}" = 0 ]; then
  printf "Nothing to commit\n"
  EXIT_CODE=1
fi

exit ${EXIT_CODE}
