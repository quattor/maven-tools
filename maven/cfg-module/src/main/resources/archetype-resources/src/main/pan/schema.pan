# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

declaration template components/${artifactId}/schema;

include { 'quattor/schema' };

type ${artifactId}_config = {
    'dummy' : string = 'OK'
} = nlist();

type ${artifactId}_component = {
    include structure_component
    'config' : config_${artifactId}
};

bind '/software/components/${artifactId}' = component_${artifactId};
