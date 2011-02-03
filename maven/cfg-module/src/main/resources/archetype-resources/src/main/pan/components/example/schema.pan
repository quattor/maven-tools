# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

declaration template components/${quattor.component}/schema;

include { 'quattor/schema' };

type ${quattor.component}_config = {
    'dummy' : string = 'OK'
} = nlist();

type ${quattor.component}_component = {
    include structure_component
    'config' : config_${quattor.component}
};

bind '/software/components/${quattor.component}' = component_${quattor.component};
