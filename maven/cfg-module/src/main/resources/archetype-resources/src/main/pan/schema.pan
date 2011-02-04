# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

declaration template components/example/schema;

include { 'quattor/schema' };

type example_config = {
    'dummy' : string = 'OK'
} = nlist();

type example_component = {
    include structure_component
    'config' : config_example
};

bind '/software/components/example' = component_example;
