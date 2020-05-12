# Auction website written with Elixir/OTP applying CQRS/ES principles

## Introduction

You have been collecting stamps, postcards, coins, banknotes, playcards, photos, posters, pins to cite only few. 

At the beginning your collection was empty and it was really easy to find new objects, you simply just searched on collectible websites entering keywords related to your collection or browsing specific topics. Numerous pages were displayed and you placed bids on interesting objects, with chance you won some of them, paid the seller including fees and shipping/handling.

For common, non rare objects, as many of them were available you just had to find the one with a good price and a seller from your country to minimize the shipping costs. You bought many of them and your collection grown.

Depending on the kind of objects you are collecting, at a certain point you will start to feel the collecting process a little bit complicated. Ok one of the pleasures of collecting is about spending time to search for your prefered objects. But when you don't find those objects even when they are listed on your prefered websites, or when you find the listed price expensive and you feel this is an over estimated price, then you feel a little bit frustrated.

This is where the story begins. 

We want :

* to help the sellers when they create auctions by giving them informations related to the objects they are selling like topics, keywords, area, year and also a quote of the object based on the sales made for this object in the same condition on our website.

* to give the buyers recommendations based on their previous purchases or based or other buyers purchases for objects close to the one they collect. We want a website that would give the buyers a quote of the objects based on the sales made on our website and why not on other websites. 

* to give the sellers the opportunity to define 3 discount periods per 12 months shifting period.

* to create a community of collectors and give them tools to create kind of hubs were they would meet and spot new items that would be of interest to each other. We want them to be able to communicate easily. 

* to give great tools to the buyers and the sellers to allow them to follow their purchases/sales, to generate invoices, to check whether they are awaiting payment, or are paid, or are shipped or received. Buyers and sellers might also be able to rate each other and to create litigation.

This might seem functionalities available on other collectible websites, but some of them are not. The quote of the objects and the opportunity to give informations to the seller when they create their auctions by adding a image recognition system are really new concepts. 

Developing a reactive, distributed, scalable, event driven website and using the right front-end tools like React.js or Elm would also give us tools that would help us make our website a success story.

## Principles

### Image recognition system

The image recognition system is going to use a **catalog of pictures**, we can expect more than 100.000 pictures only for stamps and this would grow each year by a magnitude of thousand. Postcard pictures would be over millions and would grow by a magnitude of 10th thousand per year.

Dealing with such numbers of images is a real challenge for different reasons :

* if one wants to recognize an image over a catalog of 100.000 for stamps or millionS for postcards, then the image recognition system must really be FAST and give back accurate results.

* another problem that arises is how are we going to handle missing and new pictures and at the same time take care to not create duplicate pictures ? 

#### Millions of pictures

We want our image recognition API to be really FAST, it must achieve a recognition in less than 1.5 second. And it must handle this even if hundreds of users are invoking the API. It must also be accurate and return the closest match.

It must handle rotated, inclined or **slightly** altered images (stamps might be obliterated and the API should be able to handle light obliteration, heavy obliteration would not allow us to match)

#### Do not duplicate me !

We will have a backend that will allow us to add images in different ways :

* batch : we would put multiple .jpg images in a directory with one .txt file containing informations related to the images like the area, the year or other informations and those images would be uploaded in our catalog automatically.

* UI : we would be able to upload one picture at a time by selecting the picture on our local disk and then fill the related informations like the area, year, topics or other informations.

Due to the number of pictures we will have to handle the best way to handle this is to allow the community to make proposals to add, remove, merge pictures to the catalog of pictures. Any logged in user might make a proposal and this proposal should be validated by at least a certain number of authorised users for this proposal to take place. We would be able to follow this proposals and their validations.

### Quote of objects

This is an important concept for our website and we want it to be inspired by stock market exchanges but not too close to make it comprehensible and accessible by the common mortal. 

A quote might vary depending on one to two criteria for a particular object, below are some examples :

* a stamp quote may vary depending on its condition (Mint Never Hinged, Mint Hinged, Obliterated).
* a postcard quote may vary depending on its condition (Mint, ...) and whether or not it has Circulated.
* a banknote quote may vary depending on its condition and some other conditions too.

We will compute/display the highest, average, lowest price and quantity sold for different periods like the last month, the last 3 months, 6 moths, year, year-1, year-2 and from the beginning (since we started).

A "simple" graph might be displayed too.
