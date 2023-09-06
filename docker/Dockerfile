FROM public.ecr.aws/amazonlinux/amazonlinux:latest

WORKDIR /tmp

RUN yum install nmap-ncat -y

COPY eks-tester-commands.sh /eks-tester-commands.sh
RUN chmod +x /eks-tester-commands.sh
ENTRYPOINT ["/eks-tester-commands.sh"]

WORKDIR /
CMD ["bash"]