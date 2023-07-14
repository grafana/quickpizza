package database

import (
	"encoding/json"
	"os"
	"sync"

	"github.com/grafana/quickpizza/pkg/pizza"
)

type Data struct {
	Doughs []pizza.Dough `json:"doughs"`

	// Ingredients
	OliveOils   []pizza.Ingredient `json:"olive_oils"`
	Tomatoes    []pizza.Ingredient `json:"tomatoes"`
	Mozzarellas []pizza.Ingredient `json:"mozzarellas"`
	Toppings    []pizza.Ingredient `json:"toppings"`

	// Important stuff
	Tools []string `json:"tools"`

	// Naming
	Adjectives   []string `json:"adjectives"`
	ClassicNames []string `json:"classic_names"`

	// Quotes
	Quotes []string `json:"quotes"`
}

type InMemoryDatabase struct {
	mx                  sync.Mutex
	data                Data
	lastRecommendations []pizza.Pizza
}

// Transaction provides a thread-safe, read-only view of the data in the database.
func (db *InMemoryDatabase) Transaction(readF func(data Data)) {
	db.mx.Lock()
	dataCopy := Data{}
	dataCopy.Doughs = append(dataCopy.Doughs, db.data.Doughs...)
	dataCopy.OliveOils = append(dataCopy.OliveOils, db.data.OliveOils...)
	dataCopy.Tomatoes = append(dataCopy.Tomatoes, db.data.Tomatoes...)
	dataCopy.Mozzarellas = append(dataCopy.Mozzarellas, db.data.Mozzarellas...)
	dataCopy.Toppings = append(dataCopy.Toppings, db.data.Toppings...)
	dataCopy.Tools = append(dataCopy.Tools, db.data.Tools...)
	dataCopy.Adjectives = append(dataCopy.Adjectives, db.data.Adjectives...)
	dataCopy.ClassicNames = append(dataCopy.ClassicNames, db.data.ClassicNames...)
	dataCopy.Quotes = append(dataCopy.Quotes, db.data.Quotes...)
	db.mx.Unlock()

	readF(dataCopy)
}

func (db *InMemoryDatabase) PopulateFromFile(path string) error {
	db.mx.Lock()
	defer db.mx.Unlock()

	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	err = decoder.Decode(&db.data)
	if err != nil {
		return err
	}

	return nil
}

func (d *InMemoryDatabase) PersistToFile(path string) error {
	d.mx.Lock()
	defer d.mx.Unlock()

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	err = encoder.Encode(&d.data)
	if err != nil {
		return err
	}

	return nil
}

func (db *InMemoryDatabase) SetLatestPizza(pizza pizza.Pizza) {
	db.mx.Lock()
	defer db.mx.Unlock()

	// TODO: Store only the last 10 pizzas
	db.lastRecommendations = append(db.lastRecommendations, pizza)
}

func (db *InMemoryDatabase) History() []pizza.Pizza {
	db.mx.Lock()
	defer db.mx.Unlock()

	var history []pizza.Pizza
	copy(history, db.lastRecommendations)
	return history
}
