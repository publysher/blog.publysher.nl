---
date: "2012-08-19"
title: "Using RDF to populate ZooWizard, a case study"
tags: ["zoo wizard", "linked data", "semantic web", "rdf", "python"]
description: "Extracting RDF data from a website that does not support RDF"
---

For some time, I've been keeping a small website called [ZooWizard](http://www.zoowizard.eu/). It's main purpose: to
have an outlet for two of my main hobbies: visiting zoos and programming.

One of the problems with keeping this website up to date is the secondary data, i.e. data about zoos and animals.
Until now, this data has been sourced using Wikipedia, personal experience and of course: lot's of manual data entry.

This was nice for a while because it's a great way to get started, but for some time this manual aspect has been
getting on my nerves. So, I decided to explore the possibilities of [Linked Data](http://linkeddata.org/).
This blog post is the first part in this case study: creating an information-rich collection of European zoos.

The code to create this collection can be found in my GitHub repository
[zoowizard-rdf](https://github.com/publysher/zoowizard-rdf). If you want to replicate what I've done,
please refer to the [tag v1](https://github.com/publysher/zoowizard-rdf/tags).

All the code has been written in Python 2.7 and it uses the following libraries:

* [BeautifulSoup](http://www.crummy.com/software/BeautifulSoup/bs4/doc/) for parsing HTML
* [RDFLib](http://rdflib.readthedocs.org/en/latest/index.html) for managing RDF

Finding a starting point
------------------------

One of my favorite references for obtaining information about zoos so far has been the
[ZooChat](http://www.zoochat.com/) website which contains
an
[exhaustive list of all the zoos around the world](http://www.zoochat.com/zoos/).
It's more complete than Wikipedia, so I've decided to start here.

Of course, the first problem that arises here is the fact that ZooChat contains _no linked data whatsoever_.  So,
I decided to start out by creating a dataset based on their zoo list. Since web scraping is a dirty hobby,
I won't go into too much details. Suffice it to say that the first step was a small program called `zoochat2py` which
scrapes the data into a pickled list of dictionaries like this:

{{% highlight python %}}
    { 'zoochat_id': u'43',
      'name': u'Artis Royal Zoo',
      'alternative_names': [u'Artis Zoo', u'Amsterdam Zoo', u'Natura Artis Magistra'],
      'country': u'Netherlands',
      'website': 'http://www.artis.nl/en/artis-royal-zoo/',
      'wikipedia': 'http://en.wikipedia.org/wiki/Artis_Magistra_zoo',
      'facebook': 'http://www.facebook.com/Artis',
      'twitter': 'http://twitter.com/artis',
      'map': 'http://www.zoochat.com/maps/artis-zoo',
    }
{{% /highlight %}}    

Creating an RDF Dataset
-----------------------

The next step was to create an RDF dataset based on this information. I quickly found out that creating an RDF
dataset is not trivial, and I decided first to read the
[Linked Data book](http://linkeddatabook.com/editions/1.0) and follow their advice. Go, read the book. It's really good.

### Determining cool URI's ###

The first step to consider is the Naming Scheme. Using <http://zoowizard.eu> as my basic namespace seemed like a
logical choice and I settled on using <http://zoowizard.eu/datasource/zoochat> as the URI for the dataset itself,
and <http://zoowizard.eu/datasource/zoochat/NUMBER> as the format for URIs for the individual zoos. This leaves me
free to add other third-party datasets in the future, and it won't pollute the rest of my namespace.

I briefly toyed with the idea to use hash-based URIs for the individual zoos, but when it turned out I needed some
kind of sub-URI's for the social references, I immediately went back to the previous scheme.

### Finding the right vocabulary ###

This turned out to be the hardest part of the whole exercise. I had already decided that this small dataset should
not require a new vocabulary. But how do you find the correct vocabulary for what you want to express?

In the end, I spent some time looking at published RDF resources such as
[DBpedia](http://dbpedia.org/About) and the
[BBC Wildlife Finder](http://dbpedia.org/About) and
slowly built up a list of relevant namespaces.

The most important ones are of course the original RDF and RDF Schema namespaces. Due to previous experience with
Schema.org in HTML5 I decided to include the Schema namespace as well. So I quickly ended up with:

    <http://zoowizard.eu/datasource/zoochat/43> a schema:Zoo,
        rdfs:label "Artis Royal Zoo";
        schema:addressCountry "Netherlands";
        schema:map <http://www.zoochat.com/maps/artis-zoo>;
        schema:name "Artis Royal Zoo" .

A nice first step, but this was only part of the information at my disposal. So, I turned to the
[FOAF vocabulary](http://xmlns.com/foaf/spec/#) to represent the links to various websites.
This is where I discovered that I needed to have separate URI's for the Facebook and Twitter links, because FOAF
uses a separate Class to represent an account. I decided to use the #facebook and #twitter extensions for the existing
names, resulting in the following representation:

    <http://zoowizard.eu/datasource/zoochat/43> a schema:Zoo,
            foaf:Organization;
        # ...
        foaf:account <http://zoowizard.eu/datasource/zoochat/43#facebook>,
            <http://zoowizard.eu/datasource/zoochat/43#twitter>;
        foaf:based_near "Netherlands";
        foaf:homepage <http://www.artis.nl/en/artis-royal-zoo/>;
        foaf:isPrimaryTopicOf <http://en.wikipedia.org/wiki/Artis_Magistra_zoo> .

    <http://zoowizard.eu/datasource/zoochat/43#facebook> a foaf:OnlineAccount;
        foaf:accountProfilePage <http://www.facebook.com/Artis>;
        foaf:accountServiceHomePage <http://www.facebook.com> .

    <http://zoowizard.eu/datasource/zoochat/43#twitter> a foaf:OnlineAccount;
        foaf:accountProfilePage <http://twitter.com/artis>;
        foaf:accountServiceHomePage <http://www.twitter.com> .

Yes, I cheated a bit. `foaf:accountProfilePage` is not a documented property but it seemed like the best way to denote
Facebook pages.

With this, I only needed to add skos:label and skos:prefLabel triples to represent all the available information as
RDF triples. And I ended up with this:

    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix schema: <http://schema.org/> .
    @prefix skos: <http://www.w3.org/2004/02/skos/core#> .

    <http://zoowizard.eu/datasource/zoochat/43> a schema:Zoo,
            foaf:Organization;
        rdfs:label "Artis Royal Zoo";
        schema:addressCountry "Netherlands";
        schema:map <http://www.zoochat.com/maps/artis-zoo>;
        schema:name "Artis Royal Zoo";
        skos:altLabel "Amsterdam Zoo",
            "Artis Zoo",
            "Natura Artis Magistra";
        skos:prefLabel "Artis Royal Zoo";
        foaf:account <http://zoowizard.eu/datasource/zoochat/43#facebook>,
            <http://zoowizard.eu/datasource/zoochat/43#twitter>;
        foaf:based_near "Netherlands";
        foaf:homepage <http://www.artis.nl/en/artis-royal-zoo/>;
        foaf:isPrimaryTopicOf <http://en.wikipedia.org/wiki/Artis_Magistra_zoo>,
            <http://zoowizard.eu/datasource/zoochat/43.rdf> .

    <http://zoowizard.eu/datasource/zoochat/43#facebook> a foaf:OnlineAccount;
        foaf:accountProfilePage <http://www.facebook.com/Artis>;
        foaf:accountServiceHomePage <http://www.facebook.com> .

    <http://zoowizard.eu/datasource/zoochat/43#twitter> a foaf:OnlineAccount;
        foaf:accountProfilePage <http://twitter.com/artis>;
        foaf:accountServiceHomePage <http://www.twitter.com> .

Publishing my RDF
-----------------

Now it was time to convert this graph consisting of 19,586 triples to something that could be served over the internet.
And once again, I turned to the Linked Data book to see what they suggest.

After reading the book again, I decided to describe the dataset itself using the Dublin Core and VoID vocabularies,
to use the 303 approach to keep concepts and descriptions apart, to create a separate XML file for each zoo and the
dataset, and to create an NT file containing the entire dump.

### Describing the dataset ###

This was quite easy, and for now I ended up with:

    @prefix dc: <http://purl.org/dc/terms/> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix void: <http://rdfs.org/ns/void#> .

    <http://zoowizard.eu/datasource/zoochat> a void:Dataset;
        rdfs:label "List of All Zoos Worldwide";
        dc:description "RDF description extracted from http://www.zoochat.com/zoos";
        dc:license <http://creativecommons.org/licenses/by-sa/3.0/>;
        dc:modified "2012-08-19"^^<http://www.w3.org/2001/XMLSchema#date>;
        dc:source <http://www.zoochat.com/zoos>;
        dc:title "List of All Zoos Worldwide";
        void:dataDump <http://zoowizard.eu/datasource/zoochat/all.nt>;
        void:exampleResource <http://zoowizard.eu/datasource/zoochat/43>;
        void:feature <http://www.w3.org/ns/formats/RDF_XML> .

Followed by a lot of entries like this:

    <http://zoowizard.eu/datasource/zoochat/43> void:inDataset
        <http://zoowizard.eu/datasource/zoochat> .

### Using the 303-approach ###

The 303-approach basically states that things and descriptions should be kept separated. The Linked Data book
suggests to use a different URI for the description and to relate the description and the thing by using
foaf:primaryTopic links. I decided to give my descriptions an .rdf extension, and using the power of RDFLib I could
easily extend the graph:

{{% highlight python %}}
    items = itertools.chain(g.subjects(RDF.type, SCHEMA.Zoo),
                            g.subjects(RDF.type, VOID.Dataset))

    for item in items:
        document = item + '.rdf'
        g.add((item, FOAF.isPrimaryTopicOf, URIRef(document)))
        g.add((URIRef(document), FOAF.primaryTopic, item))
{{% /highlight %}}    

### Creating the files ###

Actually creating the files turned out to be the easiest of all, once again thanks to RDFLib. It's serialization 
feature makes it a breeze to create RDF/XML files or NT files. Or even N3 output such as used in this post. 

The biggest trick was to create a relevant subgraph. So far, I've come up with this:

{{% highlight python %}}
    def create_subgraph(graph, item):
        g = rdflib.Graph()
        namespaces.init_bindings(g)

        for triple in graph.triples((item, None, None)):
            g.add(triple)

        for triple in graph.triples((None, None, item)):
            g.add(triple)

        return g
{{% /highlight %}}    

This takes care of collecting all the triples in which the required URI is either the subject or the object. It could
require a bit more transitivity, and RDFLib seems to have good utilities for that,
but it was a nice exercise nevertheless.

Serving the files
-----------------

The last step was to upload my documents to my web server and to configure Apache to use the 303 approach. Given the
lack of complexity for this dataset, I used the following rules in my config:

{{% highlight apache %}}
    RewriteEngine on
    AddType application/rdf+xml;charset=UTF-8       .rdf

    RewriteRule ^/datasource/zoochat$ http://zoowizard.eu/datasource/zoochat.rdf [redirect=303]
    RewriteRule ^/datasource/zoochat/(\d+)$ http://zoowizard.eu/datasource/zoochat/$1.rdf [redirect=303]
{{% /highlight %}}    

This approach won't work as my datasets grow, but for now it suffices.

What's next?
------------

So far, I've succeeded in creating a good RDF representation containing a list of all the zoos worldwide. There are
several next steps which I plan to undertake. They include, but are not limited to:

* Creating my own authoritive dataset based on this external dataset
* Linking this dataset to DBpedia
* Linking this dataset to Geonames
* Dynamically serving this dataset
* Generating HTML pages from this dataset
* etc.
