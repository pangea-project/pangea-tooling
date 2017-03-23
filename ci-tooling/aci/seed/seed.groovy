#!/usr/bin/env groovy

import org.yaml.snakeyaml.Yaml
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.security.Provider.Service
import com.google.common.io.ByteStreams

def apps = new Yaml().load(new FileReader(new File("${WORKSPACE}/data/applications.yaml")))

apps.each { name, config ->
  config.branch.each { branch ->
    pipelineJob("${name}-${branch}-appimage") {
     definition {
        cpsScm {
            scm {
                github("appimage-packages/${name}", "${branch}")
            }
        }
    }
  }
  }

}
