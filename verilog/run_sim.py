"""Simulate the N-element system with random integer matrices.
"""
import os
import shutil
import random
import subprocess
import argparse
import logging

import numpy as np


def run_test(num_pes, seed=0):
    """Run a simulation for a size num_pes GEMM array.

    Creates a ./sim working folder.
    """
    # Clean working folder
    if os.path.isdir('./sim'):
        shutil.rmtree('./sim')
    os.mkdir('./sim')

    # Copy Verilog Files
    for fname in os.listdir('./src'):
        if fname.endswith('.sv') or fname.endswith('.v'):
            shutil.copy('./src/' + fname, './sim')

    # Generate random integer matrices
    random.seed(seed)
    matrix_a = [random.randint(1, 2**8) for _ in range(num_pes * num_pes)]
    matrix_b = [random.randint(1, 2**8) for _ in range(num_pes * num_pes)]

    matrix_a = np.array(matrix_a).reshape(num_pes, num_pes)
    matrix_b = np.array(matrix_b).reshape(num_pes, num_pes)
    matrix_c = np.dot(matrix_a, matrix_b)

    with open(f"./sim/Adata", "w") as f_handle:
        for elem in matrix_a.T.ravel():
            f_handle.write(hex(elem)[2:] + '\n')

    with open(f"./sim/Bdata", "w") as f_handle:
        for elem in matrix_b.ravel():
            f_handle.write(hex(elem)[2:] + '\n')

    with open(f"./sim/Cdata", "w") as f_handle:
        for elem in matrix_c.T.ravel():
            f_handle.write(hex(elem)[2:] + '\n')

    logging.info("A = \n%s", str(matrix_a))
    logging.info("B = \n%s", str(matrix_b))
    logging.info("C = \n%s", str(matrix_c))

    # Execute simulation using Vivado Tools
    partnum = 'xc7vx690tffg1157-1'
    script_tcl = """
    create_project sim_project ./sim_project -part {partnum} -force
    import_files -fileset sim_1 -norecurse ./Adata
    import_files -fileset sim_1 -norecurse ./Bdata
    import_files -fileset sim_1 -norecurse ./Cdata
    import_files -fileset sim_1 -norecurse ./
    update_compile_order -fileset sim_1
    set_property top tb [get_filesets sim_1]
    set_property XELAB.MT_LEVEL off [get_filesets sim_1]
    set_property -name {{xsim.simulate.runtime}} -value {{-all}} -objects [get_filesets sim_1]
    set_property generic {{N={num_pes}}} [get_filesets sim_1]
    launch_simulation
    close_sim
    exit""".format(partnum=partnum,
                   num_pes=num_pes)

    with open("./sim/run_script.tcl", "w") as f_handle:
        f_handle.write(script_tcl)

    # Check output of simulation
    output = subprocess.check_output(['./run_vivado.sh',
                                      'sim', 'run_script.tcl'])
    output = output.decode('UTF-8')
    output_checks = []
    sim_failed = False
    for line in output.split('\n'):
        logging.info(line)
        if 'Error' in line:
            sim_failed = True
        if 'expected' in line:
            output_checks.append(line)

    if sim_failed:
        print("Simulation Failed")
        print('\n'.join(output_checks))
        return False
    print("Simulation Passed")
    return True


if __name__ == '__main__':
    # pylint: disable=invalid-name
    parser = argparse.ArgumentParser(description="Simulate N-PE GEMM Array")
    parser.add_argument('N', type=int, help="Number of elements in the PE")
    parser.add_argument('--seed', type=int, default=0, help="Seed for matrix generation")
    parser.add_argument('--verbose', dest='verbose', action='store_true',
                        help="Enable Verbose Output")
    parser.set_defaults(verbose=False)
    args = parser.parse_args()
    if args.verbose:
        logging.basicConfig(format='%(message)s', level=logging.INFO)
    run_test(args.N, args.seed)
