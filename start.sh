#!/bin/sh

echo "Use for BG run:./start.sh --build -d (docker-compose -p "joomla" up --build -d)"
echo
echo "Are you sure? (Enter 1 or 2)"
select yn in "Yes" "No"; do
    case $yn in
        Yes) break;;
        No) echo "aborting... that was close."; exit;;
    esac
done

docker-compose -p "joomla" up "$@"

