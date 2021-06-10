#!/bin/bash

for i in `seq 1 $1`; do
  for j in `seq 1 6`; do
    http $2 --quiet
  done

  for j in `seq 1 4`; do
    http $2 end-user:test --quiet
  done
  sleep 2
done