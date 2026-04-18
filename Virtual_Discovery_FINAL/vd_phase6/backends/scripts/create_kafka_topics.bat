@echo off
REM Run this once to create all required Kafka topics
REM Prerequisites: Kafka running on localhost:9092
REM CMD (not PowerShell) from C:\kafka

echo Creating Kafka topics for Accesco Virtual Discovery...

C:\kafka\bin\windows\kafka-topics.bat --create --if-not-exists --topic discovery-events --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092

C:\kafka\bin\windows\kafka-topics.bat --create --if-not-exists --topic moderation-decisions --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092

echo Done. Topics created:
C:\kafka\bin\windows\kafka-topics.bat --list --bootstrap-server localhost:9092
