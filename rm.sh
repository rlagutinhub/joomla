#!/bin/sh

echo "Docker volumes and Docker networks will not be deleted!!!"
echo "Are you sure? (Enter 1 or 2)"

select yn in "Yes" "No"; do
    case $yn in
        Yes) break;;
        No) echo "aborting... that was close."; exit;;
    esac
done

docker-compose -p "joomla" rm "$@"

