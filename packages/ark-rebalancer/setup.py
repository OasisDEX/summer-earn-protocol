from setuptools import setup, find_packages

setup(
    name="ark-rebalancer",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "web3==5.31.1",
        "requests==2.32.3",
        "mypy==1.11.0",
        "python-dotenv==1.0.1"
    ],
    entry_points={
        'console_scripts': [
            'ark-rebalancer=ark_rebalancer:main',
        ],
    },
)