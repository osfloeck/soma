"""
cli.py

Defines various CLI commands (implemented in main.py).

Author: Oskar Floeck
Date: 11-09-2025
License: MIT
"""

import click
from . import main

@click.group()
def cli():
    """Soma - A simple static site generator."""
    pass

@cli.command()
@click.option('--name', default="new-soma", help='Name for new site')
def init(name: str):
    """Init project contents."""
    main.init(name)

@cli.command()
def build():
    """Build the site."""
    main.build()

@cli.command()
@click.option('--port', default=8080, help='Port to run dev server on.')
@click.option('--dev', is_flag=True, help='Run in development mode.')
def serve(port: int, dev: bool):
    """Start local development server."""
    main.serve(port, dev)

@cli.command()
def clean():
    """Clean the build directory"""
    main.clean()
