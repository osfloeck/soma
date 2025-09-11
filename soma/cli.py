"""
cli.py

This module defines CLI commands to build the site and start a local
development server (implemented in main.py).

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
def init(name):
    """Init project contents."""
    main.init(name)

@cli.command()
def build():
    """Build the site."""
    main.build()

@cli.command()
@click.option('--port', default=8080, help='Port to run dev server on.')
def serve(port):
    """Start local development server."""
    main.serve(port)
    
@cli.command()
def clean():
    """Clean the build directory"""
    main.clean()
