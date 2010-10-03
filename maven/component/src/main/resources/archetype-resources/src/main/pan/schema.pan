${BUILD_INFO}
${LEGAL}

declaration template components/@COMP@/schema;

include { 'quattor/schema' };

type component_@COMP@ = {
    include structure_component
};

bind '/software/components/@COMP@' = component_@COMP@;
