---
date: "2012-02-19"
title: "Improving AppEngine performance: from JPA to Objectify"
tags:
  - appengine
  - gae
  - java
  - jpa
  - objectify
description: "How I migrated from JPA to Objectify to improve Google AppEngine startup performance."
---

This weekend, I have migrated my [Google AppEngine][] application [Zoo Wizard][] from JPA to [Objectify][].
This post gives a short overview of my rationale and the steps I've taken to complete this migration.


Spoiler: moving to Objectify is a good move, and apart from some differences between `@Embeddable` in
JPA and Objectify, the transition went smoothly.

Rationale
---------

When I first created the application, I opted to use the
[GAE JPA API](http://code.google.com/appengine/docs/java/datastore/jpa/overview.html) to stay in my comfort zone.
Using too many new technologies in an application is a recipe for disaster, and for a seasoned JEE-developer
GAE is challenging enough as it is.

As it turns out, using JPA to access the Google DataStore is not fun. JPA was developed as an abstraction over
relational databases, and the DataStore is anything but relational. As a result,
[many JPA features](http://code.google.com/appengine/docs/java/datastore/jpa/overview.html#Unsupported_Features_of_JPA)
just won't work on AppEngine. Furthermore,
[some DataStore features](http://code.google.com/appengine/docs/java/datastore/entities.html#Working_with_Entities)
that actually make the store performant are not available through JPA.

I was not happy.

Another problem with JPA is that it does a lot of processing on start-up to improve performance down the road.
This works great for enterprise applications,
[but not for Google AppEngine](http://paulonjava.blogspot.com/2010/12/tuning-google-appengine.html)
where instances are brought up and down almost constantly.

Alternatives
------------

So, this left me with a number of alternatives: [JDO][], [Objectify][], [Slim3][] and of course the
native [DataStore API][].
The internet told me that JDO shows the same startup delays as JPA; Slim3 also replaces SpringMVC which I am
happy to use, and the native DataStore API is one bridge too native.

Migrating
---------

So I started out migrating from JPA to Objectify. As it turns out, this was surprisingly easy. The first step
was to [include Objectify in my Maven project](http://code.google.com/p/objectify-appengine/wiki/MavenRepository).
Since I wanted to keep using Spring, I also included the
[Objectify Spring extension](http://code.google.com/p/objectify-appengine-spring/)
for ease of use.

I then updated the annotations (where necessary) to only use the
[annotations supported by Objectify](http://code.google.com/p/objectify-appengine/wiki/AnnotationReference). In my case,
this involved:

- Removing `@Embeddable`
- Adding `@Unindexed` on entity level and `@Indexed` on fields where required
- Adding `@Cached` annotations on every entity because... why not?

I then removed my `persistence.xml` and removed all JPA references from my Spring application context.

The next step was to rewrite my queries. ZooWizard is still a small application, and all the queries were
abstracted into DAO's. All in all, this took me about an hour. My development environment and Selenium tests showed
that everything worked as it should.

I was becoming quite happy.

`@Embedded` in JPA vs `@Embedded` in Objectify
----------------------------------------------

Deploying my application to GAE showed a different story. The application refused to load any of my
`@Embedded` fields. My Google skills did not help and once again, I was not happy.

As it turns out, JPA maps `@Embedded` fields differently from Objectify. Have a look at this JPA example:

{{% highlight java %}}
    @Entity class Zoo {
      @Embedded Address address;
    }

    @Embeddable class Address {
      @Basic String city;
    }
{{% /highlight %}}    

In this example, JPA by default stores the "city" field in a column called "city". Now have a look at this
Objectify example:

{{% highlight java %}}
    @Entity class Zoo {
      @Embedded Address address;
    }

    class Address {
      String city;
    }
{{% /highlight %}}    

Objectify stores the `city` field as `address.city`. Quite a difference. As it turns out, qualifying `@Embedded`
names cannot by turned off using Objectify's schema migration tools. So, I ended up with the following workaround:

{{% highlight java %}}
    @Entity class Zoo {
      @Embedded Address address;

      @PostLoad public void update(com.google.appending.api.datastore.Entity e) {
        if (address == null) {
          address = new Address();
          address.setCity((String) e.getProperty("city"));
        }
      }
    }

    class Address {
      String city;
    }
{{% /highlight %}}    

The `@PostLoad` method ensured that entities previously stored using JPA were still loaded correctly using Objectify.
Given the fact that ZooWizard still contains a small number of entities, I did not mind too much, but for large
applications this might be a showstopper.

I then proceeded loading and saving each entity using my Admin GUI. For large migrations,
I would have opted for Task queues.

Cleaning up
-----------

The last step was to remove everything I no longer needed:

- Objectify does not need the DataNucleus enhancement, improving my build speed;
- Many Spring/JPA libraries could be removed from my build. Some examples:
    - `org.springframework:spring-orm:jar`
    - `org.springframework:spring-jdbc:jar`
    - `com.google.appengine.orm:datanucleus-appengine:jar`
    - `javax.jdo:jdo-api:jar`
    - `javax.transaction:jta:jar`

Being Happy
-----------

The move from JPA to Objectify was a good move. The Objectify API maps very well on the native DataStore API and
forces you to think in AppEngine terms. As a happy aside, the size of my WAR file has been reduced by ~2Mb and
startup time on my development environment has been reduced by 20%.

[Google AppEngine]: http://code.google.com/appengine
[Zoo Wizard]: http://www.zoowizard.eu/index
[Objectify]: http://code.google.com/p/objectify-appengine/
[JDO]: http://code.google.com/appengine/docs/java/datastore/jdo/overview.html
[Datastore API]: http://code.google.com/appengine/docs/java/datastore/entities.html
[Slim3]: http://sites.google.com/site/slim3appengine/
