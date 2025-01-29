# WDL to run VEP on a single input file with no parallelization
# Writes as --tab output by default for simplicity

# Copyright (c) 2024-Present, Ryan L. Collins and the Dana-Farber Cancer Institute
# Contact: Ryan Collins <Ryan_Collins@dfci.harvard.edu>
# Distributed under the terms of the GNU GPL v2.0


version 1.0


workflow SimpleVep {
  input {
    File variant_file
    File? variant_file_index
    String input_format = "vcf"

    File reference_fasta
    File vep_cache_tarball # VEP cache tarball downloaded from Ensembl

    Array[String] vep_options = [""]
    String vep_assembly = "GRCh38"
    Int vep_version = 110

    String vep_docker = "vanallenlab/g2c-vep:latest"
  }

  call RunVep {
    input:
      variant_file = variant_file,
      variant_file_index = variant_file_index,
      input_format = input_format,
      reference_fasta = reference_fasta,
      vep_cache_tarball = vep_cache_tarball,
      vep_options = vep_options,
      vep_assembly = vep_assembly,
      vep_version = vep_version,
      docker = vep_docker
  }

  output {
    File annotated_variants = RunVep.annotated_variants
  }
}


task RunVep {
  input {
    File variant_file
    File? variant_file_index
    String input_format
    String output_file_prefix

    File reference_fasta
    File vep_cache_tarball
    Array[String] vep_options
    String vep_assembly

    Int vep_max_sv_size = 50
    Int vep_version = 110

    Float mem_gb = 7.5
    Int n_cpu = 4
    Int? disk_gb

    String docker
  }

  String out_filename = output_file_prefix + ".vep.tsv"
  Int default_disk_gb = ceil(10 * size([variant_file, vep_cache_tarball, reference_fasta], "GB")) + 50

  command <<<
    set -eu -o pipefail

    # Unpack contents of cache into $VEP_CACHE/
    # Note that $VEP_CACHE is a default ENV variable set in VEP docker
    tar -xzvf ~{vep_cache_tarball} -C $VEP_CACHE/

    vep \
      --input_file ~{variant_file} \
      --format ~{input_format} \
      --output_file ~{out_filename} \
      --tab \
      --verbose \
      --force_overwrite \
      --species homo_sapiens \
      --assembly ~{vep_assembly} \
      --max_sv_size ~{vep_max_sv_size} \
      --offline \
      --cache \
      --dir_cache $VEP_CACHE/ \
      --cache_version ~{vep_version} \
      --dir_plugins $VEP_PLUGINS/ \
      --fasta ~{reference_fasta} \
      --minimal \
      --nearest gene \
      --distance 10000 \
      --numbers \
      --hgvs \
      --no_escape \
      --symbol \
      --canonical \
      --domains \
      ~{sep=" " vep_options}

    gzip -f ~{out_filename}

  >>>

  output {
    File annotated_variants = "~{out_filename}.gz"
  }

  runtime {
    docker: docker
    memory: mem_gb + " GB"
    cpu: n_cpu
    disks: "local-disk " + select_first([disk_gb, default_disk_gb]) + " HDD"
    bootDiskSizeGb: 25
    preemptible: 3
  }
}

