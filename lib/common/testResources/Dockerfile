FROM public.ecr.aws/amazonlinux/amazonlinux:latest
WORKDIR /
RUN yum install nc sudo gcc gcc-c++ -y
COPY eks.sh /eks-runtime-tests.sh
RUN chmod +x /eks-runtime-tests.sh
ENTRYPOINT ["/eks-runtime-tests.sh"]
CMD ["bash"]