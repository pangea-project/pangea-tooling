#!/bin/sh -x

cd /opt/mycroft/skills/ && rm -r mycroft-pairing.mycroftai
git clone https://github.com/bhush9/skill-pairing
mv skill-pairing mycroft-pairing.mycroftai

chown -Rv phablet mycroft-pairing.mycroftai || true
